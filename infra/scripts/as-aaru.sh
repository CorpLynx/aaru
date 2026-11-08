#!/usr/bin/env bash
# Aaru: run a command as the aaru service user
# SSH admits only the admin account (harden-host.sh sets AllowUsers), so the
# operator reaches the service user through sudo. Plain `sudo -u aaru` leaves
# out the user's systemd session, so `systemctl --user` and rootless Podman
# fail; this sets it up, starts in the service user's home and passes stdin
# through, so secrets can still be piped in over SSH.
#
# harden-host.sh installs a root-owned copy as /usr/local/sbin/as-aaru (sudo
# must never run a file the service user can edit) and lets the admin run it
# without a password prompt, since a piped SSH command has no terminal for one
# (/etc/sudoers.d/aaru-as). Use that copy:
#
#   sudo as-aaru                                     a login shell as aaru
#   sudo as-aaru systemctl --user status litellm     one command
#   terraform output -raw app_auth_key \
#     | ssh <admin>@<host> sudo as-aaru aaru/infra/scripts/set-tailscale-authkey.sh
#
# Relative paths resolve from the service user's home (~aaru).
set -euo pipefail

SERVICE_USER="aaru"

[ "$(id -u)" -eq 0 ] || { echo "ERROR: run with sudo" >&2; exit 1; }
id "${SERVICE_USER}" >/dev/null 2>&1 || { echo "ERROR: user ${SERVICE_USER} does not exist (run harden-host.sh)" >&2; exit 1; }

uid="$(id -u "${SERVICE_USER}")"
home="$(getent passwd "${SERVICE_USER}" | cut -d: -f6)"
runtime="/run/user/${uid}"
# The user manager runs without a login only when the user lingers.
[ -S "${runtime}/bus" ] \
    || { echo "ERROR: no systemd user session for ${SERVICE_USER}; run: loginctl enable-linger ${SERVICE_USER}" >&2; exit 1; }

cd "${home}"
umask 027   # spec §4a, as for the service user's own shells
[ $# -gt 0 ] || set -- bash --login
exec runuser -u "${SERVICE_USER}" -- env -i \
    HOME="${home}" USER="${SERVICE_USER}" LOGNAME="${SERVICE_USER}" SHELL=/bin/bash \
    PATH="${home}/.local/bin:/usr/local/bin:/usr/bin:/bin" \
    LANG="${LANG:-C.UTF-8}" TERM="${TERM:-dumb}" \
    XDG_RUNTIME_DIR="${runtime}" DBUS_SESSION_BUS_ADDRESS="unix:path=${runtime}/bus" \
    "$@"
