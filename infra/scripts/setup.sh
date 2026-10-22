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
echo "  # PostgreSQL superuser (aaru) — used only for administration and backups"
echo "  printf '%s' \"\$(openssl rand -hex 32)\" | podman secret create postgres-password -"
echo ""
echo "  # One database role per service; each password goes into the role and its URL"
echo "  for svc in litellm openwebui; do"
echo "    pw=\$(openssl rand -hex 32)"
echo "    printf '%s' \"\$pw\" | podman secret create \"\$svc-db-password\" -"
echo "    printf 'postgresql://%s:%s@postgres:5432/%s' \"\$svc\" \"\$pw\" \"\$svc\" | podman secret create \"\$svc-database-url\" -"
echo "  done"
echo ""
echo "  printf '%s' \"sk-\$(openssl rand -hex 32)\" | podman secret create litellm-master-key -"
echo "  printf '%s' 'YOUR_CLOUDFLARE_TUNNEL_TOKEN' | podman secret create cloudflared-token -"
echo ""
echo "  # After LiteLLM is up: a virtual key for Open WebUI (never the master key)"
echo "  printf '%s' 'sk-OPENWEBUI_VIRTUAL_KEY' | podman secret create openai-api-key -"
echo ""
echo "If postgres-data already exists from an earlier setup, create the roles with:"
echo "  podman exec postgres /docker-entrypoint-initdb.d/10-aaru-databases.sh"
echo ""
echo "=== Enable services ==="
echo "  systemctl --user start aaru-ingress-network.service aaru-internal-network.service aaru-admin-network.service"
echo "  systemctl --user enable --now postgres.service"
echo "  systemctl --user enable --now llamacpp.service"
echo "  systemctl --user enable --now litellm.service"
echo "  systemctl --user enable --now openwebui.service"
echo "  systemctl --user enable --now cloudflared.service"
echo "  systemctl --user enable --now dozzle.service"
echo "  systemctl --user enable --now aaru-backup.timer"
echo ""
echo "Dozzle (log viewer) will be available at http://127.0.0.1:8088"
echo "Access via Tailscale or SSH tunnel only — never expose publicly."
echo ""
echo "Backup timer: daily at 03:00 UTC (with up to 5 min randomized delay)"
echo "Configure AARU_S3_BUCKET and AARU_KMS_KEY_ARN in the timer unit before enabling."
echo "Done. Review and run the commands above."