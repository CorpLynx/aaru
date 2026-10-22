#!/usr/bin/env bash
# Aaru Server Setup Script
# Run as the aaru service user (not root).
# Prerequisites: Fedora Server with Podman, firewalld, kernel >= 6.18.4

set -euo pipefail

QUADLET_DIR="${HOME}/.config/containers/systemd"
AARU_DIR="${HOME}/aaru"

echo "=== Aaru Server Setup ==="
echo "User: $(whoami)"
echo "Home: ${HOME}"

# Create directories
mkdir -p "${QUADLET_DIR}"
mkdir -p "${AARU_DIR}/infra/config"
mkdir -p "${AARU_DIR}/models"
mkdir -p "${AARU_DIR}/data"

# Copy Quadlet units
echo "Installing Quadlet units..."
cp "${AARU_DIR}/infra/quadlet/"*.container "${QUADLET_DIR}/"
cp "${AARU_DIR}/infra/quadlet/"*.network "${QUADLET_DIR}/"
cp "${AARU_DIR}/infra/quadlet/"*.volume "${QUADLET_DIR}/"

# Reload systemd
echo "Reloading systemd..."
systemctl --user daemon-reload

# Create secrets (example — replace with actual values)
echo ""
echo "=== Create secrets ==="
echo "Run the following commands to create required secrets:"
echo ""
echo "  printf '%s' 'YOUR_LITELLM_MASTER_KEY' | podman secret create litellm-master-key -"
echo "  printf '%s' 'postgresql://aaru:PASSWORD@postgres:5432/aaru' | podman secret create database-url -"
echo "  printf '%s' 'YOUR_POSTGRES_PASSWORD' | podman secret create postgres-password -"
echo "  printf '%s' 'YOUR_OPENAI_API_KEY' | podman secret create openai-api-key -"
echo "  printf '%s' 'YOUR_CLOUDFLARE_TUNNEL_TOKEN' | podman secret create cloudflared-token -"
echo ""
echo "=== Enable services ==="
echo "  systemctl --user enable --now aaru-internal-network.service"
echo "  systemctl --user enable --now postgres.service"
echo "  systemctl --user enable --now llamacpp.service"
echo "  systemctl --user enable --now litellm.service"
echo "  systemctl --user enable --now openwebui.service"
echo "  systemctl --user enable --now cloudflared.service"
echo "  systemctl --user enable --now dozzle.service"
echo ""
echo "Dozzle (log viewer) will be available at http://127.0.0.1:8088"
echo "Access via Tailscale or SSH tunnel only — never expose publicly."
echo "Done. Review and run the commands above."