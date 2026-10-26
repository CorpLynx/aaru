#!/usr/bin/env bash
# Aaru Host Tailscale (admin access)
# Installs Tailscale on the host from Tailscale's signed Fedora repository and
# joins the tailnet as tag:aaru-host, so admins SSH in over the tailnet
# (spec §4a). Members never reach this node; the policy in
# infra/terraform/tailscale allows only group:aaru-admins to port 22.
#
# Run as root. The one-time auth key is read from stdin:
#   terraform -chdir=infra/terraform/tailscale output -raw host_auth_key \
#     | ssh <admin>@<host> sudo aaru/infra/scripts/tailscale-host.sh
#
# Then lock SSH down to the tailnet:
#   sudo infra/scripts/harden-host.sh --admin-user <admin> --ssh-from tailscale0 --apply
# (run that from a session that already arrives over tailscale0, or the
# lockout check stops it).

set -euo pipefail

REPO_URL="https://pkgs.tailscale.com/stable/fedora/tailscale.repo"

[ "$(id -u)" -eq 0 ] || { echo "ERROR: run as root (sudo)"; exit 1; }
[ -t 0 ] && { echo "ERROR: pipe the auth key into this script (terraform output -raw host_auth_key)"; exit 1; }

KEY_FILE="$(umask 077; mktemp)"
trap 'rm -f "${KEY_FILE}"' EXIT
tr -d '[:space:]' > "${KEY_FILE}"
grep -q '^tskey-auth-' "${KEY_FILE}" || { echo "ERROR: stdin is not a Tailscale auth key (tskey-auth-...)"; exit 1; }

if ! rpm -q tailscale >/dev/null 2>&1; then
    echo "Adding Tailscale's repository (packages are GPG-signed)..."
    # dnf5 and dnf4 spell the repository command differently.
    dnf config-manager addrepo --from-repofile="${REPO_URL}" 2>/dev/null \
        || dnf config-manager --add-repo "${REPO_URL}"
    dnf install -y tailscale
fi
systemctl enable --now tailscaled

if tailscale status >/dev/null 2>&1; then
    echo "Already logged in:"
    tailscale status --self --peers=false
    exit 0
fi

# No DNS, route or exit-node changes on the host: the tailnet is only an SSH path.
tailscale up --auth-key="file:${KEY_FILE}" --hostname=aaru-host \
    --advertise-tags=tag:aaru-host --accept-dns=false --accept-routes=false
echo ""
tailscale status --self --peers=false
echo ""
echo "Next: harden-host.sh --ssh-from tailscale0 (see the header of this script)."
