#!/usr/bin/env bash
# Aaru Backup Credentials Setup
# Installs the backup IAM user's access key as a Podman secret and writes the
# non-secret settings to ~/.config/aaru/backup.env for aaru-backup.service.
#
# The access key is read from stdin as the JSON that `aws iam create-access-key`
# prints, so it never touches a file, an argument list or the shell history.
# From the machine with admin AWS credentials:
#
#   aws iam create-access-key --user-name <backup_user_name> --output json \
#     | ssh aaru@<host> aaru/infra/scripts/set-backup-credentials.sh \
#         --bucket <bucket_name> --kms-key-arn <kms_key_arn> --region <region>
#
# The three values are outputs of infra/terraform/backup. Rotate the key
# quarterly (spec §10): create a new one, re-run this script, then delete the
# old key with `aws iam delete-access-key`.

set -euo pipefail

SECRET_NAME="${AARU_BACKUP_AWS_SECRET:-aaru-backup-aws}"
ENV_FILE="${HOME}/.config/aaru/backup.env"
BUCKET="" KMS_KEY_ARN="" REGION=""

while [ $# -gt 0 ]; do
    case "$1" in
        --bucket) BUCKET="${2:?--bucket needs a value}"; shift 2 ;;
        --kms-key-arn) KMS_KEY_ARN="${2:?--kms-key-arn needs a value}"; shift 2 ;;
        --region) REGION="${2:?--region needs a value}"; shift 2 ;;
        -h|--help) sed -n '2,17p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "ERROR: unknown argument: $1"; exit 1 ;;
    esac
done
[ -n "${BUCKET}" ] && [ -n "${KMS_KEY_ARN}" ] && [ -n "${REGION}" ] \
    || { echo "ERROR: --bucket, --kms-key-arn and --region are required"; exit 1; }
case "${KMS_KEY_ARN}" in
    arn:aws:kms:*:key/*) ;;
    *) echo "ERROR: --kms-key-arn must be a key ARN (arn:aws:kms:<region>:<account>:key/<id>)"; exit 1 ;;
esac
[ -t 0 ] && { echo "ERROR: pipe the output of 'aws iam create-access-key' into this script"; exit 1; }

command -v podman >/dev/null 2>&1 || { echo "ERROR: podman not found"; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "ERROR: python3 not found"; exit 1; }

echo "=== Installing backup credentials ==="
# Turn the create-access-key JSON into a shared-credentials file on a pipe.
python3 -c '
import json, sys
k = json.load(sys.stdin)["AccessKey"]
sys.stdout.write("[default]\naws_access_key_id = %s\naws_secret_access_key = %s\n" % (k["AccessKeyId"], k["SecretAccessKey"]))
' | podman secret create --replace "${SECRET_NAME}" - >/dev/null
echo "  Podman secret ${SECRET_NAME} installed"

mkdir -p "$(dirname "${ENV_FILE}")"
(
    umask 077
    cat > "${ENV_FILE}" <<EOF
# Written by infra/scripts/set-backup-credentials.sh; read by aaru-backup.service.
AARU_S3_BUCKET=${BUCKET}
AARU_KMS_KEY_ARN=${KMS_KEY_ARN}
AWS_REGION=${REGION}
EOF
)
echo "  ${ENV_FILE} written"
echo ""
echo "Test it now rather than waiting for the timer:"
echo "  systemctl --user start aaru-backup.service && journalctl --user -u aaru-backup.service -n 30"
