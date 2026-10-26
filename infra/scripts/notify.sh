#!/usr/bin/env bash
# Aaru Notify
# Sends one alert to the operator through ntfy (https://ntfy.sh or self-hosted).
# Used by healthcheck.sh and by aaru-notify@.service (OnFailure= hooks).
#
# Usage:
#   infra/scripts/notify.sh <priority> <title> [message]
#     priority: min, low, default, high or urgent
#
# Configuration, in ~/.config/aaru/alerts.env (mode 0600):
#   AARU_NTFY_URL    topic URL, e.g. https://ntfy.sh/<long-random-topic>
#   AARU_NTFY_TOKEN  optional access token for a protected topic
# Without AARU_NTFY_URL the alert only goes to the journal.
#
# Alerts carry check names and states, never prompts, keys or user data.

set -euo pipefail

ALERTS_ENV="${HOME}/.config/aaru/alerts.env"
# shellcheck source=/dev/null
[ -f "${ALERTS_ENV}" ] && . "${ALERTS_ENV}"

PRIORITY="${1:?usage: notify.sh <priority> <title> [message]}"
TITLE="${2:?missing title}"
MESSAGE="${3:-${TITLE}}"
HOST="$(hostname -s)"

echo "aaru-alert [${PRIORITY}] ${TITLE}: ${MESSAGE}"
[ -n "${AARU_NTFY_URL:-}" ] || exit 0

WORK_DIR="$(umask 077; mktemp -d)"
trap 'rm -rf "${WORK_DIR:?}"' EXIT
args=(-fsS --max-time 15 -o /dev/null -H "Title: [${HOST}] ${TITLE}" -H "Priority: ${PRIORITY}" -H "Tags: aaru")
if [ -n "${AARU_NTFY_TOKEN:-}" ]; then
    printf 'Authorization: Bearer %s\n' "${AARU_NTFY_TOKEN}" > "${WORK_DIR}/auth.hdr"
    args+=(-H @"${WORK_DIR}/auth.hdr")
fi
curl "${args[@]}" --data-binary "${MESSAGE}" "${AARU_NTFY_URL}" \
    || echo "aaru-alert: delivery to ntfy failed" >&2
