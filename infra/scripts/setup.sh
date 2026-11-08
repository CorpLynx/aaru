#!/usr/bin/env bash
# Aaru Server Setup Script
# Run as the aaru service user (not root). From the admin account:
#   sudo as-aaru aaru/infra/scripts/setup.sh [options]
# Prerequisites: Fedora Server with Podman and firewalld, SELinux enforcing, and
# a kernel with current driver support for the inference GPU.
#
# Usage: infra/scripts/setup.sh [--ingress tailscale|cloudflare|both] [--inference llamacpp|vllm]
#   --ingress    how members reach the app. tailscale (default) is the interim
#                path until Cloudflare is live (spec §9); both is for the switch-over.
#   --inference  llamacpp (default) on the production AMD host, vllm on the
#                NVIDIA test host.
#
# Only the chosen ingress and inference units are installed. Every Quadlet unit
# starts at boot, and one without its secret or GPU fails there and keeps
# healthcheck.sh alerting. Re-running with another choice removes the units no
# longer chosen, unless they are running (stop them first).

set -euo pipefail

INGRESS="tailscale"
INFERENCE="llamacpp"
while [ $# -gt 0 ]; do
    case "$1" in
        --ingress) INGRESS="${2:?--ingress needs tailscale, cloudflare or both}"; shift 2 ;;
        --inference) INFERENCE="${2:?--inference needs llamacpp or vllm}"; shift 2 ;;
        -h|--help) sed -n '2,17p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "ERROR: unknown argument: $1"; exit 1 ;;
    esac
done
case "${INGRESS}" in
    tailscale) INGRESS_UNITS=(tailscale) ;;
    cloudflare) INGRESS_UNITS=(cloudflared) ;;
    both) INGRESS_UNITS=(tailscale cloudflared) ;;
    *) echo "ERROR: --ingress must be tailscale, cloudflare or both"; exit 1 ;;
esac
case "${INFERENCE}" in
    llamacpp|vllm) ;;
    *) echo "ERROR: --inference must be llamacpp or vllm"; exit 1 ;;
esac
# Units that are installed only when chosen; every other unit always is.
OPTIONAL_UNITS=(cloudflared tailscale llamacpp vllm)
CHOSEN_UNITS=("${INGRESS_UNITS[@]}" "${INFERENCE}")
chosen() { printf '%s\n' "${CHOSEN_UNITS[@]}" | grep -qx "$1"; }
optional() { printf '%s\n' "${OPTIONAL_UNITS[@]}" | grep -qx "$1"; }

QUADLET_DIR="${HOME}/.config/containers/systemd"
SYSTEMD_USER_DIR="${HOME}/.config/systemd/user"
AARU_DIR="${HOME}/aaru"
ME="$(id -un)"

echo "=== Aaru Server Setup ==="
echo "User:      ${ME}"
echo "Home:      ${HOME}"
echo "Ingress:   ${INGRESS_UNITS[*]}"
echo "Inference: ${INFERENCE}"

# User services stop at logout and do not start at boot unless the user lingers.
if [ "$(loginctl show-user "${ME}" --property=Linger --value 2>/dev/null)" != "yes" ]; then
    echo ""
    echo "WARNING: lingering is off for ${ME}. The containers stop when ${ME} logs out"
    echo "         and do not start at boot. As the admin user, run:"
    echo "           sudo loginctl enable-linger ${ME}"
fi

# Create directories
mkdir -p "${QUADLET_DIR}" "${SYSTEMD_USER_DIR}" "${HOME}/.config/aaru"
mkdir -p "${AARU_DIR}/infra/config"
mkdir -p "${AARU_DIR}/models"
mkdir -p "${AARU_DIR}/data"

# Copy Quadlet units: always the core ones, the optional ones only when chosen.
echo "Installing Quadlet units..."
for unit in "${AARU_DIR}/infra/quadlet/"*.container; do
    name="$(basename "${unit}" .container)"
    if ! optional "${name}" || chosen "${name}"; then
        cp "${unit}" "${QUADLET_DIR}/"
        continue
    fi
    [ -f "${QUADLET_DIR}/${name}.container" ] || continue
    # Installed earlier but not chosen now: remove it, unless it is running.
    if systemctl --user is-active --quiet "${name}.service"; then
        echo "  WARNING: ${name}.service is running but not chosen; left installed."
        echo "           Stop it (systemctl --user stop ${name}.service) and re-run setup.sh to remove it."
    else
        rm -f "${QUADLET_DIR}/${name}.container"
        rm -rf "${QUADLET_DIR}/${name}.container.d"
        echo "  removed ${name}.container (not chosen)"
    fi
done
cp "${AARU_DIR}/infra/quadlet/"*.network "${QUADLET_DIR}/"
cp "${AARU_DIR}/infra/quadlet/"*.volume "${QUADLET_DIR}/"

# Host-specific drop-ins (model, memory limit) for the installed units. They are
# gitignored, so each host keeps its own; an inference unit without one has no
# model to serve.
for dropin_dir in "${AARU_DIR}/infra/quadlet/"*.container.d; do
    unit_dir="$(basename "${dropin_dir}")"
    [ -f "${QUADLET_DIR}/${unit_dir%.d}" ] || continue
    if [ -f "${dropin_dir}/local.conf" ]; then
        mkdir -p "${QUADLET_DIR}/${unit_dir}"
        cp "${dropin_dir}/local.conf" "${QUADLET_DIR}/${unit_dir}/local.conf"
        echo "  ${unit_dir}/local.conf installed"
    else
        echo "  NOTE: no ${dropin_dir#"${AARU_DIR}"/}/local.conf; copy local.conf.example"
        echo "        and size it before starting ${unit_dir%.container.d}.service"
    fi
done

# The web app mounts the rendered legal pages; the directories must exist for it to start.
mkdir -p "${AARU_DIR}/legal/site/.well-known"
if [ ! -f "${AARU_DIR}/legal/site/terms.html" ]; then
    echo "  NOTE: legal pages not rendered; copy legal/legal.conf.example to legal.conf,"
    echo "        fill it in and run infra/scripts/render-legal.sh (see legal/README.md)"
fi
if [ "${INFERENCE}" = llamacpp ] && [ ! -f "${AARU_DIR}/infra/config/llama-swap/config.yaml" ]; then
    echo "  NOTE: no infra/config/llama-swap/config.yaml; copy config.yaml.example and"
    echo "        list the staged models before starting llamacpp.service"
fi
if [ ! -f "${AARU_DIR}/infra/config/litellm/models.yaml" ]; then
    echo "  NOTE: no infra/config/litellm/models.yaml; copy models.yaml.example and"
    echo "        point the aliases at the served model before starting LiteLLM"
fi
if [ "${INFERENCE}" = vllm ]; then
    echo "  NOTE: vLLM serves one model, so use the vLLM block in models.yaml. The web app's"
    echo "        RAG uses the \"embed\" alias (openwebui.container); without one, uploads fail."
fi

# Backup, health check and alert units are plain systemd units, not Quadlet files.
echo "Installing backup and monitoring units..."
cp "${AARU_DIR}/infra/quadlet/"aaru-*.service "${AARU_DIR}/infra/quadlet/"aaru-*.timer "${SYSTEMD_USER_DIR}/"

# Reload systemd
echo "Reloading systemd..."
systemctl --user daemon-reload

# Dozzle reads container logs through the Podman API socket (dozzle.container).
echo "Enabling the Podman API socket (for Dozzle)..."
systemctl --user enable --now podman.socket

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
echo ""
echo "  # Shared by LiteLLM and llama-swap; llama-swap refuses requests without it"
echo "  printf '%s' \"sk-\$(openssl rand -hex 32)\" | podman secret create llama-swap-api-key -"
echo ""
echo "  # Signs web app sessions; keep it stable across restarts"
echo "  printf '%s' \"\$(openssl rand -hex 32)\" | podman secret create openwebui-secret-key -"
echo ""
if chosen cloudflared; then
    echo "  # The tunnel connector token comes from the Cloudflare stack."
    echo "  # On the machine holding the Terraform state:"
    echo "  #   cd infra/terraform/cloudflare && terraform output -raw tunnel_token"
    echo "  # then pipe it in here (or run infra/scripts/set-cloudflared-token.sh):"
    echo "  printf '%s' 'YOUR_CLOUDFLARE_TUNNEL_TOKEN' | podman secret create cloudflared-token -"
    echo ""
fi
if chosen tailscale; then
    echo "  # Interim member access over Tailscale (until Cloudflare is live). On the machine"
    echo "  # holding the Terraform state, in infra/terraform/tailscale:"
    echo "  #   terraform output -raw app_auth_key \\"
    echo "  #     | ssh <admin>@<host> sudo as-aaru aaru/infra/scripts/set-tailscale-authkey.sh"
    echo ""
fi
echo "  # The web app's own LiteLLM key (openai-api-key) is created once LiteLLM runs; see below."
echo ""
echo "  # Backups: see infra/terraform/backup/README.md for the bucket, key and credentials"
echo "  infra/scripts/set-backup-credentials.sh"
echo ""
echo "If postgres-data already exists from an earlier setup, create the roles with:"
echo "  podman exec postgres /docker-entrypoint-initdb.d/10-aaru-databases.sh"
echo ""
echo "=== Start services ==="
echo "  # Quadlet units start at boot through their [Install] section; they cannot be enabled."
echo "  systemctl --user start aaru-ingress-network.service aaru-internal-network.service aaru-admin-network.service"
echo "  systemctl --user start postgres.service"
echo "  systemctl --user start ${INFERENCE}.service"
echo "  systemctl --user start litellm.service"
echo ""
echo "  # The web app does not start without its own LiteLLM virtual key (never the master"
echo "  # key). Once LiteLLM answers (curl -s http://127.0.0.1:4000/health/liveliness):"
echo "  infra/scripts/member.sh webapp-key"
echo "  systemctl --user start openwebui.service"
echo ""
echo "  # Create the web app admin BEFORE members can reach it: the first account created"
echo "  # becomes admin even with sign-up off. From your machine, as the admin user:"
echo "  #   ssh -L 3000:127.0.0.1:3000 <admin>@<host>   then open http://localhost:3000 and sign up"
echo "  # (use localhost in Chrome or Firefox: they keep the app's secure cookies there; Safari does not)."
echo "  # verify.sh fails while member ingress is up and no admin exists."
echo ""
for unit in "${INGRESS_UNITS[@]}"; do
    echo "  systemctl --user start ${unit}.service"
done
echo "  systemctl --user start dozzle.service"
echo "  systemctl --user enable --now aaru-backup.timer"
echo "  systemctl --user enable --now aaru-healthcheck.timer"
echo ""
echo "Dozzle (log viewer) will be available at http://127.0.0.1:8088"
echo "Access via Tailscale or SSH tunnel only — never expose publicly."
echo ""
echo "Backup timer: daily at 03:00 UTC (with up to 5 min randomized delay)."
echo "It reads ~/.config/aaru/backup.env; set-backup-credentials.sh writes it."
echo ""
echo "Alerts go to ntfy: put AARU_NTFY_URL=https://ntfy.sh/<long-random-topic> in"
echo "${HOME}/.config/aaru/alerts.env (chmod 600), then test with:"
echo "  infra/scripts/notify.sh default 'test alert'"
echo "  infra/scripts/healthcheck.sh --print"
echo "Done. Review and run the commands above."
