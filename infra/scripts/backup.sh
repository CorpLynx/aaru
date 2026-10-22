#!/usr/bin/env bash
# Aaru Encrypted S3 Backup Script
# Backs up PostgreSQL, Open WebUI data, and config to S3 with SSE-KMS.
#
# Prerequisites:
#   - AWS CLI configured with credentials for aaru-backup-role (or IAM user)
#   - Environment variables:
#       AARU_S3_BUCKET   — S3 bucket name (e.g., aaru-backups-prod)
#       AARU_KMS_KEY_ARN — Customer-managed KMS key ARN
#       AARU_BACKUP_DIR  — Local staging directory (default: /tmp/aaru-backup)
#       POSTGRES_CONTAINER — Podman container name (default: postgres)
#       POSTGRES_USER    — PostgreSQL user (default: aaru)
#   - Optional: age public key for client-side encryption (AARU_AGE_PUBKEY)

set -euo pipefail

# --- Configuration ---
S3_BUCKET="${AARU_S3_BUCKET:?AARU_S3_BUCKET must be set}"
KMS_KEY_ARN="${AARU_KMS_KEY_ARN:?AARU_KMS_KEY_ARN must be set}"
BACKUP_DIR="${AARU_BACKUP_DIR:-/tmp/aaru-backup}"
PG_CONTAINER="${POSTGRES_CONTAINER:-postgres}"
PG_USER="${POSTGRES_USER:-aaru}"
TIMESTAMP=$(date -u +"%Y%m%dT%H%M%SZ")
BACKUP_NAME="aaru-backup-${TIMESTAMP}"
ARCHIVE="${BACKUP_DIR}/${BACKUP_NAME}.tar.gz"
S3_PREFIX="s3://${S3_BUCKET}/aaru-backups"

# --- Cleanup on exit ---
cleanup() {
    rm -rf "${BACKUP_DIR:?}" 2>/dev/null || true
}
trap cleanup EXIT

# --- Preflight checks ---
echo "=== Aaru Encrypted S3 Backup ==="
echo "Timestamp: ${TIMESTAMP}"
echo "S3 bucket: ${S3_BUCKET}"
echo "KMS key:   ${KMS_KEY_ARN}"

command -v aws >/dev/null 2>&1 || { echo "ERROR: aws CLI not found"; exit 1; }
command -v podman >/dev/null 2>&1 || { echo "ERROR: podman not found"; exit 1; }

# Verify S3 bucket access
aws s3 ls "s3://${S3_BUCKET}/" >/dev/null 2>&1 || { echo "ERROR: Cannot access S3 bucket"; exit 1; }

# --- Create staging directory ---
mkdir -p "${BACKUP_DIR}/postgres"
mkdir -p "${BACKUP_DIR}/openwebui"
mkdir -p "${BACKUP_DIR}/config"

# --- Step 1: PostgreSQL dump ---
echo "[1/5] Dumping PostgreSQL..."
podman exec "${PG_CONTAINER}" pg_dumpall -U "${PG_USER}" -c 2>/dev/null \
    | gzip > "${BACKUP_DIR}/postgres/pg_dumpall.sql.gz"
PG_SIZE=$(du -sh "${BACKUP_DIR}/postgres/pg_dumpall.sql.gz" | cut -f1)
echo "  PostgreSQL dump: ${PG_SIZE}"

# --- Step 2: Open WebUI data volume ---
echo "[2/5] Archiving Open WebUI data..."
podman volume inspect openwebui-data >/dev/null 2>&1 && \
    podman run --rm -v openwebui-data:/data:ro -v "${BACKUP_DIR}/openwebui:/backup:z" \
        docker.io/library/alpine:latest \
        tar czf /backup/openwebui-data.tar.gz -C /data . 2>/dev/null || \
    echo "  WARNING: openwebui-data volume not found, skipping"

# --- Step 3: Configuration files ---
echo "[3/5] Archiving configuration..."
cp -r "${HOME}/aaru/infra/config/"* "${BACKUP_DIR}/config/" 2>/dev/null || true
cp -r "${HOME}/.config/containers/systemd/"* "${BACKUP_DIR}/config/quadlet/" 2>/dev/null || true

# --- Step 4: Create archive ---
echo "[4/5] Creating archive..."
tar czf "${ARCHIVE}" -C "${BACKUP_DIR}" postgres openwebui config
ARCHIVE_SIZE=$(du -sh "${ARCHIVE}" | cut -f1)
echo "  Archive: ${ARCHIVE} (${ARCHIVE_SIZE})"

# Optional: client-side encryption with age
if [ -n "${AARU_AGE_PUBKEY:-}" ] && command -v age >/dev/null 2>&1; then
    echo "  Encrypting with age (client-side)..."
    age -r "${AARU_AGE_PUBKEY}" -o "${ARCHIVE}.age" "${ARCHIVE}"
    rm -f "${ARCHIVE}"
    ARCHIVE="${ARCHIVE}.age"
    ARCHIVE_SIZE=$(du -sh "${ARCHIVE}" | cut -f1)
    echo "  Encrypted archive: ${ARCHIVE} (${ARCHIVE_SIZE})"
fi

# --- Step 5: Upload to S3 with SSE-KMS ---
echo "[5/5] Uploading to S3..."
aws s3 cp "${ARCHIVE}" "${S3_PREFIX}/${BACKUP_NAME}.tar.gz" \
    --sse aws:kms \
    --sse-kms-key-id "${KMS_KEY_ARN}" \
    --storage-class STANDARD_IA

# Verify upload
S3_SIZE=$(aws s3 ls "${S3_PREFIX}/${BACKUP_NAME}.tar.gz" --human-readable | awk '{print $3, $4}')
echo "  Uploaded: ${S3_SIZE}"

# --- Success ---
echo ""
echo "=== Backup complete ==="
echo "  Local:  ${ARCHIVE}"
echo "  S3:     ${S3_PREFIX}/${BACKUP_NAME}.tar.gz"
echo "  Size:   ${ARCHIVE_SIZE}"
echo "  Time:   $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
echo ""
echo "To restore:"
echo "  aws s3 cp ${S3_PREFIX}/${BACKUP_NAME}.tar.gz /tmp/restore.tar.gz"
echo "  tar xzf /tmp/restore.tar.gz -C /tmp/restore/"
echo "  # Then restore PostgreSQL: gunzip -c pg_dumpall.sql.gz | podman exec -i postgres psql -U aaru"
echo "  # And restore Open WebUI data: podman volume import openwebui-data /tmp/restore/openwebui-data.tar.gz"