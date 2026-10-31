#!/usr/bin/env bash
# Aaru Encrypted S3 Backup Script
# Backs up PostgreSQL, the web app data volume, and config to S3 with SSE-KMS.
# Runs from aaru-backup.service, which loads ~/.config/aaru/backup.env.
#
# Prerequisites:
#   - The backup bucket, KMS key and IAM user from infra/terraform/backup
#   - The aaru-backup-aws Podman secret: an AWS shared-credentials file for
#     that user (infra/scripts/set-backup-credentials.sh creates it)
#   - Environment variables:
#       AARU_S3_BUCKET     — S3 bucket name
#       AARU_KMS_KEY_ARN   — customer-managed KMS key ARN
#       AWS_REGION         — the bucket's region
#       AARU_BACKUP_DIR    — parent of the staging directory (default: ~/aaru/backup-staging)
#       POSTGRES_CONTAINER — Podman container name (default: postgres)
#       POSTGRES_USER      — PostgreSQL user (default: aaru)
#   - Optional: AARU_AGE_PUBKEY, an age recipient for client-side encryption
#   - Optional: AWS_ENDPOINT_URL, an S3-compatible endpoint for testing (e.g. LocalStack)
#
# Layout in the bucket, each prefix with its own lifecycle rule:
#   daily/    every run
#   weekly/   Sunday runs, copied server-side from daily/
#   monthly/  runs on the 1st, copied server-side from daily/

set -euo pipefail

# --- Configuration ---
S3_BUCKET="${AARU_S3_BUCKET:?AARU_S3_BUCKET must be set}"
KMS_KEY_ARN="${AARU_KMS_KEY_ARN:?AARU_KMS_KEY_ARN must be set}"
REGION="${AWS_REGION:?AWS_REGION must be set}"
STAGING_PARENT="${AARU_BACKUP_DIR:-${HOME}/aaru/backup-staging}"
PG_CONTAINER="${POSTGRES_CONTAINER:-postgres}"
PG_USER="${POSTGRES_USER:-aaru}"
AWS_SECRET="${AARU_BACKUP_AWS_SECRET:-aaru-backup-aws}"
# Pinned by digest to 2.37.13; never use a floating tag (see litellm.container).
AWS_CLI_IMAGE="docker.io/amazon/aws-cli@sha256:d32864c20087d486f5988c3e70817d67a73f584a47535cada9ad97e0ea1e5196"
TIMESTAMP=$(date -u +"%Y%m%dT%H%M%SZ")
BACKUP_NAME="aaru-backup-${TIMESTAMP}"
STARTED=$(date +%s)

# --- Staging: a fresh private directory, removed on exit ---
mkdir -p "${STAGING_PARENT}"
BACKUP_DIR="$(umask 077; mktemp -d "${STAGING_PARENT}/run.XXXXXX")"
cleanup() {
    rm -rf "${BACKUP_DIR:?}" 2>/dev/null || true
}
trap cleanup EXIT

# aws <args> — the AWS CLI in a container. Credentials come from the Podman
# secret, so they never sit in the environment or on the host filesystem.
aws() {
    local endpoint=()
    [ -n "${AWS_ENDPOINT_URL:-}" ] && endpoint=(-e AWS_ENDPOINT_URL="${AWS_ENDPOINT_URL}")
    podman run --rm "${endpoint[@]+"${endpoint[@]}"}" \
        --secret "${AWS_SECRET},type=mount,target=aws-credentials" \
        -e AWS_SHARED_CREDENTIALS_FILE=/run/secrets/aws-credentials \
        -e AWS_REGION="${REGION}" \
        -v "${BACKUP_DIR}:/backup:ro,Z" \
        "${AWS_CLI_IMAGE}" "$@"
}

# --- Preflight checks ---
echo "=== Aaru Encrypted S3 Backup ==="
echo "Timestamp: ${TIMESTAMP}"
echo "S3 bucket: ${S3_BUCKET}"

command -v podman >/dev/null 2>&1 || { echo "ERROR: podman not found"; exit 1; }
podman secret exists "${AWS_SECRET}" || { echo "ERROR: Podman secret ${AWS_SECRET} not found (run set-backup-credentials.sh)"; exit 1; }
aws s3api head-bucket --bucket "${S3_BUCKET}" >/dev/null || { echo "ERROR: cannot access s3://${S3_BUCKET}"; exit 1; }

mkdir -p "${BACKUP_DIR}/postgres" "${BACKUP_DIR}/openwebui" "${BACKUP_DIR}/config/quadlet"

# --- Step 1: PostgreSQL dump ---
echo "[1/5] Dumping PostgreSQL..."
podman exec "${PG_CONTAINER}" pg_dumpall -U "${PG_USER}" -c | gzip > "${BACKUP_DIR}/postgres/pg_dumpall.sql.gz"
[ -s "${BACKUP_DIR}/postgres/pg_dumpall.sql.gz" ] || { echo "ERROR: PostgreSQL dump is empty"; exit 1; }
echo "  PostgreSQL dump: $(du -sh "${BACKUP_DIR}/postgres/pg_dumpall.sql.gz" | cut -f1)"

# --- Step 2: Web app data volume ---
echo "[2/5] Archiving web app data..."
if podman volume exists openwebui-data; then
    podman volume export openwebui-data --output "${BACKUP_DIR}/openwebui/openwebui-data.tar"
    echo "  Web app data: $(du -sh "${BACKUP_DIR}/openwebui/openwebui-data.tar" | cut -f1)"
else
    echo "  WARNING: openwebui-data volume not found, skipping"
fi

# --- Step 3: Configuration files (no secrets; those live in Podman's secret store) ---
echo "[3/5] Archiving configuration..."
cp -r "${HOME}/aaru/infra/config/." "${BACKUP_DIR}/config/"
cp -r "${HOME}/.config/containers/systemd/." "${BACKUP_DIR}/config/quadlet/"

# --- Step 4: Create archive ---
echo "[4/5] Creating archive..."
ARCHIVE="${BACKUP_DIR}/${BACKUP_NAME}.tar.gz"
tar czf "${ARCHIVE}" -C "${BACKUP_DIR}" postgres openwebui config

if [ -n "${AARU_AGE_PUBKEY:-}" ]; then
    command -v age >/dev/null 2>&1 || { echo "ERROR: AARU_AGE_PUBKEY is set but age is not installed"; exit 1; }
    echo "  Encrypting with age (client-side)..."
    age -r "${AARU_AGE_PUBKEY}" -o "${ARCHIVE}.age" "${ARCHIVE}"
    rm -f "${ARCHIVE}"
    ARCHIVE="${ARCHIVE}.age"
fi
OBJECT="$(basename "${ARCHIVE}")"
SIZE=$(stat -c %s "${ARCHIVE}")
SHA256=$(sha256sum "${ARCHIVE}" | cut -d' ' -f1)
echo "  Archive: ${OBJECT} ($(du -sh "${ARCHIVE}" | cut -f1))"

# --- Step 5: Upload to S3 with SSE-KMS, then verify ---
echo "[5/5] Uploading to S3..."
aws s3 cp "/backup/${OBJECT}" "s3://${S3_BUCKET}/daily/${OBJECT}" \
    --sse aws:kms --sse-kms-key-id "${KMS_KEY_ARN}" \
    --metadata "sha256=${SHA256}" --only-show-errors

# The object must have the local size and the checksum recorded at upload.
read -r REMOTE_SIZE REMOTE_SHA256 < <(aws s3api head-object --bucket "${S3_BUCKET}" --key "daily/${OBJECT}" \
    --query '[ContentLength, Metadata.sha256]' --output text)
if [ "${REMOTE_SIZE}" != "${SIZE}" ] || [ "${REMOTE_SHA256}" != "${SHA256}" ]; then
    echo "ERROR: uploaded object does not match (size ${REMOTE_SIZE} vs ${SIZE})"
    exit 1
fi
echo "  Verified: daily/${OBJECT}"

copy_to() {
    aws s3 cp "s3://${S3_BUCKET}/daily/${OBJECT}" "s3://${S3_BUCKET}/$1/${OBJECT}" \
        --sse aws:kms --sse-kms-key-id "${KMS_KEY_ARN}" --metadata-directive COPY --only-show-errors
    echo "  Copied to $1/"
}
[ "$(date -u +%u)" = "7" ] && copy_to weekly
[ "$(date -u +%d)" = "01" ] && copy_to monthly

# --- Success (no contents, credentials or URLs in the journal) ---
echo ""
echo "=== Backup complete ==="
echo "  Object:   s3://${S3_BUCKET}/daily/${OBJECT}"
echo "  Size:     ${SIZE} bytes"
echo "  SHA-256:  ${SHA256}"
echo "  Duration: $(( $(date +%s) - STARTED ))s"
echo ""
echo "To restore (see infra/terraform/backup/README.md):"
echo "  aws s3 cp s3://${S3_BUCKET}/daily/${OBJECT} ."
echo "  # Check sha256sum against the object's sha256 metadata, decrypt with age if used, then:"
echo "  tar xzf ${BACKUP_NAME}.tar.gz"
echo "  gunzip -c postgres/pg_dumpall.sql.gz | podman exec -i postgres psql -U aaru"
echo "  podman volume import openwebui-data openwebui/openwebui-data.tar"
