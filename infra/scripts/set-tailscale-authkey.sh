#!/usr/bin/env bash
# Aaru Tailscale Auth Key Setup
# Installs the one-time auth key for the tailscale container (interim member
# access) as the tailscale-authkey Podman secret. The key is read from stdin,
# so it never touches a file, an argument list or the shell history:
#
#   terraform -chdir=infra/terraform/tailscale output -raw app_auth_key \
#     | ssh aaru@<host> aaru/infra/scripts/set-tailscale-authkey.sh
#
# The key only logs the node in once; afterwards the node key lives in the
# tailscale-state volume. Re-run only to re-authenticate a wiped node.

set -euo pipefail

SECRET_NAME="tailscale-authkey"

command -v podman >/dev/null 2>&1 || { echo "ERROR: podman not found"; exit 1; }
[ -t 0 ] && { echo "ERROR: pipe the auth key into this script (terraform output -raw app_auth_key)"; exit 1; }

KEY="$(tr -d '[:space:]')"
case "${KEY}" in
    tskey-auth-*) ;;
    *) echo "ERROR: stdin is not a Tailscale auth key (tskey-auth-...)"; exit 1 ;;
esac
printf '%s' "${KEY}" | podman secret create --replace "${SECRET_NAME}" - >/dev/null
echo "Podman secret ${SECRET_NAME} installed. Start the node with:"
echo "  systemctl --user start tailscale.service && podman logs -f tailscale"
