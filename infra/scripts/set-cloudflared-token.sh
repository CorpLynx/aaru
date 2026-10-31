#!/usr/bin/env bash
# Aaru Cloudflare Tunnel Token Setup
# Installs the Cloudflare Tunnel connector token as a Podman secret for the
# cloudflared container.
#
# Prerequisites:
#   - The Cloudflare stack applied (infra/terraform/cloudflare)
#   - Terraform available and the stack's backend initialised
#   - Podman, running as the aaru service user
#
# The token is read from Terraform output and piped straight into Podman, so
# it is never written to a file or shown in a shell history.

set -euo pipefail

STACK_DIR="${AARU_TF_STACK_DIR:-${HOME}/aaru/infra/terraform/cloudflare}"
SECRET_NAME="${CLOUDFLARE_SECRET_NAME:-cloudflared-token}"

if ! command -v podman >/dev/null 2>&1; then
    echo "ERROR: podman not found"
    exit 1
fi

if [ ! -d "${STACK_DIR}" ]; then
    echo "ERROR: stack directory not found: ${STACK_DIR}"
    echo "       Set AARU_TF_STACK_DIR to the cloudflare stack's path."
    exit 1
fi

echo "=== Reading tunnel token from Terraform ==="
cd "${STACK_DIR}"

if [ ! -f .terraform/terraform.tfstate ] && ! terraform state list >/dev/null 2>&1; then
    echo "ERROR: Terraform state not initialised in ${STACK_DIR}"
    echo "       Run: terraform init -backend-config=backend.hcl"
    exit 1
fi

# The token output is sensitive; -raw prints it without the quotes and
# without the "sensitive value" warning block.
TOKEN="$(terraform output -raw tunnel_token 2>/dev/null || true)"

if [ -z "${TOKEN}" ]; then
    echo "ERROR: no tunnel token in Terraform output."
    echo "       If the stack runs in adopt mode (create_tunnel = false), the token"
    echo "       was never written to state — take it from the Cloudflare dashboard"
    echo "       and create the secret manually:"
    echo "         podman secret create ${SECRET_NAME} -"
    exit 1
fi

echo "Token length: ${#TOKEN} characters"

echo "=== Creating Podman secret ==="
if podman secret inspect "${SECRET_NAME}" >/dev/null 2>&1; then
    echo "Secret '${SECRET_NAME}' already exists — replacing it."
    podman secret rm "${SECRET_NAME}"
fi

printf '%s' "${TOKEN}" | podman secret create "${SECRET_NAME}" -

echo ""
echo "Secret '${SECRET_NAME}' created."
echo ""
echo "Start or restart the tunnel connector:"
echo "  systemctl --user restart cloudflared.service"
echo ""
echo "Then confirm the connector is connected:"
echo "  systemctl --user status cloudflared.service"
echo "  podman logs --tail 20 cloudflared"
echo ""
echo "A healthy connector logs registered conns and serving at the edge."
