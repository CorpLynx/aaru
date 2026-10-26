#!/usr/bin/env bash
# Aaru Weekly Lynis Audit (spec §4a)
# Runs `lynis audit system` and turns the report into a login banner for
# admins at /etc/motd.d/aaru-lynis, which pam_motd shows after SSH login.
#
# Installed by harden-host.sh as /usr/local/sbin/aaru-lynis-audit (root-owned,
# so the root timer never runs a file the service user can edit) and run by
# aaru-lynis-audit.timer every week. Run it by hand the same way:
#   sudo systemctl start aaru-lynis-audit.service
#
# The banner is mode 0640 root:wheel: admins read it at login, the service
# user and other local accounts cannot. The full results stay in
# /var/log/lynis.log and /var/log/lynis-report.dat.

set -euo pipefail

REPORT=/var/log/lynis-report.dat
LOG=/var/log/lynis.log
BANNER=/etc/motd.d/aaru-lynis
STATE_DIR=/var/lib/aaru
TARGET=80   # spec §4a: hardening index above 80
SHOW_WARNINGS=5

[ "$(id -u)" -eq 0 ] || { echo "ERROR: run as root"; exit 1; }
command -v lynis >/dev/null 2>&1 || { echo "ERROR: lynis not installed"; exit 1; }
mkdir -p "${STATE_DIR}" /etc/motd.d

# --cronjob: no colors, no pauses. Findings do not change the exit status.
# Lynis writes ${LOG} and ${REPORT} by default.
lynis audit system --cronjob --quiet >/dev/null

value() { grep -m1 "^$1=" "${REPORT}" | cut -d= -f2-; }
INDEX="$(value hardening_index)"
ENDED="$(value report_datetime_end)"
VERSION="$(value lynis_version)"
WARNINGS="$(grep -c '^warning\[\]=' "${REPORT}" || true)"
SUGGESTIONS="$(grep -c '^suggestion\[\]=' "${REPORT}" || true)"

# Change since the previous audit.
PREV="$(cat "${STATE_DIR}/lynis-last-index" 2>/dev/null || true)"
TREND=""
if [ -n "${PREV}" ] && [ -n "${INDEX}" ]; then
    delta=$(( INDEX - PREV ))
    if [ "${delta}" -gt 0 ]; then TREND=" (+${delta} since last week)"
    elif [ "${delta}" -lt 0 ]; then TREND=" (${delta} since last week)"
    else TREND=" (unchanged)"; fi
fi
[ -n "${INDEX}" ] && echo "${INDEX}" > "${STATE_DIR}/lynis-last-index"

if [ -z "${INDEX}" ]; then
    STATUS="no hardening index in the report"
elif [ "${INDEX}" -ge "${TARGET}" ] && [ "${WARNINGS}" -eq 0 ]; then
    STATUS="OK"
else
    STATUS="ACTION NEEDED"
fi

# warning[]=TEST-ID|Text|details|solution|
WARNING_LINES="$(grep '^warning\[\]=' "${REPORT}" | cut -d= -f2- \
    | awk -F'|' -v n="${SHOW_WARNINGS}" 'NR <= n { printf "    ! %-10s %s\n", $1, substr($2, 1, 60) }')"

tmp="$(mktemp)"
{
    echo ""
    echo "  ── Lynis security audit · ${ENDED:-unknown} · ${STATUS} ──"
    echo "    Hardening index  ${INDEX:-?} / 100${TREND}   target ${TARGET}+ (spec §4a)"
    echo "    Warnings         ${WARNINGS}"
    echo "    Suggestions      ${SUGGESTIONS}"
    if [ -n "${WARNING_LINES}" ]; then
        echo "${WARNING_LINES}"
        [ "${WARNINGS}" -gt "${SHOW_WARNINGS}" ] && echo "    … and $(( WARNINGS - SHOW_WARNINGS )) more"
    fi
    echo "    Findings: sudo grep -E '^(warning|suggestion)' ${REPORT}"
    echo "    Full log: sudo less ${LOG}"
    echo "    Lynis ${VERSION:-?} · next audit runs weekly (systemctl list-timers aaru-lynis-audit.timer)"
    echo ""
} > "${tmp}"
install -m 0640 -o root -g wheel "${tmp}" "${BANNER}"
rm -f "${tmp}"
restorecon -F "${BANNER}" 2>/dev/null || true

echo "lynis: index ${INDEX:-?}${TREND}, ${WARNINGS} warning(s), ${SUGGESTIONS} suggestion(s) — ${STATUS}"
