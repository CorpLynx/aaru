#!/usr/bin/env bash
# Aaru Restore Drill (spec §10: before onboarding members, then quarterly)
# Proves a backup can actually be restored, without touching live data:
#
#   1. downloads a backup from S3 and checks its SHA-256 against the value
#      recorded at upload (and decrypts it if it was age-encrypted),
#   2. loads the PostgreSQL dump into a throwaway PostgreSQL container with no
#      network, and imports the web app volume into a throwaway volume,
#   3. compares row counts in the restored databases with the live ones,
#   4. records the result for healthcheck.sh, which alerts when the last
#      successful drill is more than 100 days old.
#
# Run on the host as the aaru service user, with the backup credentials that
# set-backup-credentials.sh installed (the backup user can read as well as write).
#
# Usage:
#   infra/scripts/restore-drill.sh                 # the newest daily backup
#   infra/scripts/restore-drill.sh <s3-key>        # e.g. monthly/aaru-backup-20261101T030000Z.tar.gz
#
# Environment (beyond ~/.config/aaru/backup.env):
#   AARU_AGE_IDENTITY  age identity file, needed only for .age backups
#   AARU_DRILL_DIR     parent of the work directory (default: ~/aaru/backup-staging)

set -euo pipefail

BACKUP_ENV="${HOME}/.config/aaru/backup.env"
# shellcheck source=/dev/null
[ -f "${BACKUP_ENV}" ] && . "${BACKUP_ENV}"
S3_BUCKET="${AARU_S3_BUCKET:?AARU_S3_BUCKET must be set (run set-backup-credentials.sh)}"
REGION="${AWS_REGION:?AWS_REGION must be set}"
AWS_SECRET="${AARU_BACKUP_AWS_SECRET:-aaru-backup-aws}"
STATE_FILE="${XDG_STATE_HOME:-${HOME}/.local/state}/aaru/restore-drill"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# The same pinned images the deployment runs.
AWS_CLI_IMAGE="$(sed -n 's/^AWS_CLI_IMAGE="\(.*\)"$/\1/p' "${REPO_ROOT}/infra/scripts/backup.sh")"
PG_IMAGE="$(sed -n 's/^Image=//p' "${REPO_ROOT}/infra/quadlet/postgres.container")"
[ -n "${AWS_CLI_IMAGE}" ] && [ -n "${PG_IMAGE}" ] || { echo "ERROR: cannot read pinned images from the repo"; exit 1; }

KEY="${1:-}"
TAG="aaru-restore-drill-$$"
mkdir -p "${AARU_DRILL_DIR:-${HOME}/aaru/backup-staging}" "$(dirname "${STATE_FILE}")"
WORK="$(umask 077; mktemp -d "${AARU_DRILL_DIR:-${HOME}/aaru/backup-staging}/drill.XXXXXX")"
cleanup() {
    podman rm -f "${TAG}" >/dev/null 2>&1 || true
    podman volume rm -f "${TAG}-pg" "${TAG}-owui" >/dev/null 2>&1 || true
    rm -rf "${WORK:?}"
}
trap cleanup EXIT

aws() {
    podman run --rm \
        --secret "${AWS_SECRET},type=mount,target=aws-credentials" \
        -e AWS_SHARED_CREDENTIALS_FILE=/run/secrets/aws-credentials \
        -e AWS_REGION="${REGION}" \
        -v "${WORK}:/work:Z" \
        "${AWS_CLI_IMAGE}" "$@"
}

FAIL=0
pass() { printf '  PASS  %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf '  FAIL  %s\n' "$1"; }

echo "=== Aaru Restore Drill ==="

# --- 1. Download and verify ---------------------------------------------------
if [ -z "${KEY}" ]; then
    KEY="$(aws s3api list-objects-v2 --bucket "${S3_BUCKET}" --prefix daily/ \
        --query 'sort_by(Contents, &LastModified)[-1].Key' --output text)"
fi
[ -n "${KEY}" ] && [ "${KEY}" != "None" ] || { echo "ERROR: no backup found in s3://${S3_BUCKET}/daily/"; exit 1; }
OBJECT="$(basename "${KEY}")"
echo "Backup: s3://${S3_BUCKET}/${KEY}"

aws s3 cp "s3://${S3_BUCKET}/${KEY}" "/work/${OBJECT}" --only-show-errors
EXPECTED="$(aws s3api head-object --bucket "${S3_BUCKET}" --key "${KEY}" --query 'Metadata.sha256' --output text)"
ACTUAL="$(sha256sum "${WORK}/${OBJECT}" | cut -d' ' -f1)"
if [ "${EXPECTED}" = "${ACTUAL}" ]; then
    pass "downloaded file matches the SHA-256 recorded at upload"
else
    fail "SHA-256 mismatch (recorded ${EXPECTED:-none}, got ${ACTUAL})"
    exit 1
fi

ARCHIVE="${WORK}/${OBJECT}"
if [[ "${OBJECT}" == *.age ]]; then
    [ -n "${AARU_AGE_IDENTITY:-}" ] || { echo "ERROR: ${OBJECT} is age-encrypted; set AARU_AGE_IDENTITY"; exit 1; }
    age -d -i "${AARU_AGE_IDENTITY}" -o "${ARCHIVE%.age}" "${ARCHIVE}"
    rm -f "${ARCHIVE}"
    ARCHIVE="${ARCHIVE%.age}"
    pass "decrypted with the age identity"
fi
mkdir -p "${WORK}/x"
tar xzf "${ARCHIVE}" -C "${WORK}/x"
for part in postgres/pg_dumpall.sql.gz openwebui/openwebui-data.tar config; do
    if [ -e "${WORK}/x/${part}" ]; then pass "archive contains ${part}"; else fail "archive is missing ${part}"; fi
done

# --- 2. Restore into throwaway containers -------------------------------------
echo "Restoring PostgreSQL into a throwaway container (no network)..."
podman volume create "${TAG}-pg" >/dev/null
podman run -d --name "${TAG}" --network none \
    -e POSTGRES_USER=aaru -e POSTGRES_DB=aaru -e POSTGRES_PASSWORD="$(openssl rand -hex 16)" \
    -v "${TAG}-pg:/var/lib/postgresql/data:Z" "${PG_IMAGE}" >/dev/null
for _ in $(seq 1 60); do
    podman exec "${TAG}" pg_isready -U aaru -d aaru >/dev/null 2>&1 && break
    sleep 1
done
podman exec "${TAG}" pg_isready -U aaru -d aaru >/dev/null 2>&1 || { fail "throwaway PostgreSQL did not start"; exit 1; }

gunzip -c "${WORK}/x/postgres/pg_dumpall.sql.gz" \
    | podman exec -i "${TAG}" psql -U aaru -d postgres -q -v ON_ERROR_STOP=0 >/dev/null 2> "${WORK}/restore.err" || true
# A fresh cluster already has the superuser and its database; errors about
# those are expected. Anything else means the dump did not load cleanly.
unexpected="$(grep -E '^(psql:.*)?ERROR' "${WORK}/restore.err" \
    | grep -vE 'role "aaru" already exists|database "aaru" already exists|cannot drop the currently open database|current user cannot be dropped' || true)"
if [ -z "${unexpected}" ]; then
    pass "dump loaded without unexpected errors"
else
    fail "dump loaded with $(printf '%s\n' "${unexpected}" | wc -l | tr -d ' ') unexpected error(s):"
    printf '%s\n' "${unexpected}" | head -5 | sed 's/^/        /'
fi

echo "Importing the web app volume into a throwaway volume..."
podman volume create "${TAG}-owui" >/dev/null
if podman volume import "${TAG}-owui" "${WORK}/x/openwebui/openwebui-data.tar" 2>/dev/null; then
    pass "web app volume imports ($(tar -tf "${WORK}/x/openwebui/openwebui-data.tar" | wc -l | tr -d ' ') entries)"
else
    fail "web app volume did not import"
fi

# --- 3. Compare with the live databases ---------------------------------------
count() {  # count <container> <db> <table>
    podman exec "$1" psql -U aaru -d "$2" -tA -c "select count(*) from \"$3\"" 2>/dev/null | tr -dc '0-9'
}
printf '\n  %-34s %10s %10s\n' "table" "restored" "live"
for spec in openwebui:user openwebui:chat openwebui:file litellm:LiteLLM_VerificationToken; do
    db="${spec%%:*}"; table="${spec#*:}"
    restored="$(count "${TAG}" "${db}" "${table}")"
    live="$(count postgres "${db}" "${table}")"
    printf '  %-34s %10s %10s\n' "${db}.${table}" "${restored:-?}" "${live:-?}"
    if [ -z "${restored}" ]; then
        fail "${db}.${table} missing from the restore"
    elif [ -n "${live}" ] && [ "${live}" -gt 0 ] && [ "${restored}" -eq 0 ]; then
        fail "${db}.${table} is empty in the restore but has ${live} rows live"
    fi
done
echo "  (Live counts may be higher: they include changes made since the backup.)"

# --- 4. Record ---------------------------------------------------------------
echo ""
if [ "${FAIL}" -eq 0 ]; then
    printf 'date=%s\nobject=%s\nresult=passed\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "${KEY}" > "${STATE_FILE}"
    echo "Restore drill PASSED for ${KEY}. Recorded in ${STATE_FILE}."
else
    printf 'date=%s\nobject=%s\nresult=failed\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "${KEY}" > "${STATE_FILE}"
    echo "Restore drill FAILED (${FAIL} problem(s)) for ${KEY}."
    exit 1
fi
