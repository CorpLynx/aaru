#!/usr/bin/env bash
# Aaru Health Check (spec §10: alert on disk exhaustion, failed backups,
# unexpected restarts and sustained overload)
# Runs every 5 minutes from aaru-healthcheck.timer as the aaru service user.
# Each check is OK or FAIL; notify.sh fires only when a check changes state,
# so a lasting problem alerts once and its recovery alerts once.
#
# Thresholds (override in ~/.config/aaru/alerts.env):
#   AARU_DISK_MAX_PCT       85   per filesystem holding / or the service home
#   AARU_MEM_MIN_AVAIL_PCT  10   MemAvailable as a share of MemTotal
#   AARU_GPU_MAX_TEMP_C     90   any GPU hwmon sensor
#   AARU_RESTARTS_MAX       3    systemd restarts per service since the last check
#   AARU_BACKUP_MAX_AGE_H   26   since the last successful backup
#
# Usage: infra/scripts/healthcheck.sh [--print]   (--print: show every check, alert nothing)

set -uo pipefail

ALERTS_ENV="${HOME}/.config/aaru/alerts.env"
# shellcheck source=/dev/null
[ -f "${ALERTS_ENV}" ] && . "${ALERTS_ENV}"
DISK_MAX="${AARU_DISK_MAX_PCT:-85}"
MEM_MIN="${AARU_MEM_MIN_AVAIL_PCT:-10}"
GPU_MAX="${AARU_GPU_MAX_TEMP_C:-90}"
RESTARTS_MAX="${AARU_RESTARTS_MAX:-3}"
BACKUP_MAX_H="${AARU_BACKUP_MAX_AGE_H:-26}"
GATEWAY="${AARU_GATEWAY:-http://127.0.0.1:4000}"
SERVICES=(postgres litellm openwebui cloudflared tailscale llamacpp vllm dozzle)

STATE_DIR="${XDG_STATE_HOME:-${HOME}/.local/state}/aaru"
STATE_FILE="${STATE_DIR}/health.state"
NOTIFY="$(dirname "${BASH_SOURCE[0]}")/notify.sh"
PRINT=false
[ "${1:-}" = "--print" ] && PRINT=true
mkdir -p "${STATE_DIR}"
touch "${STATE_FILE}"
rm -f "${STATE_FILE}.new"

declare -A NOW_STATE NOW_DETAIL
check() { NOW_STATE["$1"]="$2"; NOW_DETAIL["$1"]="$3"; }

# --- Disk ---
for path in / "${HOME}"; do
    pct="$(df --output=pcent "${path}" 2>/dev/null | tail -1 | tr -dc '0-9')"
    mount="$(df --output=target "${path}" 2>/dev/null | tail -1)"
    [ -n "${pct}" ] || continue
    if [ "${pct}" -ge "${DISK_MAX}" ]; then
        check "disk:${mount}" FAIL "${mount} is ${pct}% full (limit ${DISK_MAX}%)"
    else
        check "disk:${mount}" OK "${mount} at ${pct}%"
    fi
done

# --- Memory ---
read -r total avail < <(awk '/^MemTotal:/{t=$2} /^MemAvailable:/{a=$2} END{print t, a}' /proc/meminfo)
avail_pct=$(( avail * 100 / total ))
if [ "${avail_pct}" -lt "${MEM_MIN}" ]; then
    check memory FAIL "only ${avail_pct}% of memory available (limit ${MEM_MIN}%)"
else
    check memory OK "${avail_pct}% available"
fi

# --- GPU temperature (any hwmon sensor under a DRM device) ---
max_temp=""
for sensor in /sys/class/drm/card*/device/hwmon/hwmon*/temp*_input; do
    [ -r "${sensor}" ] || continue
    t=$(( $(cat "${sensor}") / 1000 ))
    if [ -z "${max_temp}" ] || [ "${t}" -gt "${max_temp}" ]; then
        max_temp="${t}"
    fi
done
if [ -n "${max_temp}" ]; then
    if [ "${max_temp}" -ge "${GPU_MAX}" ]; then
        check gpu-temp FAIL "GPU at ${max_temp}°C (limit ${GPU_MAX}°C)"
    else
        check gpu-temp OK "GPU at ${max_temp}°C"
    fi
fi

# --- Failed user units ---
failed="$(systemctl --user list-units --state=failed --no-legend --plain 2>/dev/null | awk '{print $1}' | xargs)"
if [ -n "${failed}" ]; then
    check failed-units FAIL "failed: ${failed}"
else
    check failed-units OK "none failed"
fi

# --- Containers: running, healthy, not restart-looping ---
for svc in "${SERVICES[@]}"; do
    [ -f "${HOME}/.config/containers/systemd/${svc}.container" ] || continue
    active="$(systemctl --user is-active "${svc}.service" 2>/dev/null)"
    health="$(podman inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{end}}' "${svc}" 2>/dev/null)"
    restarts="$(systemctl --user show "${svc}.service" --property=NRestarts --value 2>/dev/null)"
    prev_restarts="$(awk -v k="restarts:${svc}" '$1 == k {print $2}' "${STATE_FILE}")"
    echo "restarts:${svc} ${restarts:-0}" >> "${STATE_FILE}.new"
    if [ "${active}" != "active" ]; then
        check "svc:${svc}" FAIL "${svc} is ${active:-unknown}"
    elif [ "${health}" = "unhealthy" ]; then
        check "svc:${svc}" FAIL "${svc} is running but unhealthy"
    elif [ -n "${prev_restarts}" ] && [ $(( ${restarts:-0} - prev_restarts )) -ge "${RESTARTS_MAX}" ]; then
        check "svc:${svc}" FAIL "${svc} restarted $(( restarts - prev_restarts )) times in 5 minutes"
    else
        check "svc:${svc}" OK "${svc} ${active}${health:+, ${health}}"
    fi
done

# --- Gateway ---
code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "${GATEWAY}/health/liveliness" 2>/dev/null || echo 000)"
if [ "${code}" = "200" ]; then
    check gateway OK "LiteLLM answering"
else
    check gateway FAIL "LiteLLM liveliness returned ${code}"
fi

# --- Backup freshness ---
if systemctl --user is-enabled aaru-backup.timer >/dev/null 2>&1; then
    last="$(systemctl --user show aaru-backup.service --property=ExecMainExitTimestamp --value 2>/dev/null)"
    result="$(systemctl --user show aaru-backup.service --property=Result --value 2>/dev/null)"
    if [ -z "${last}" ] || [ "${last}" = "n/a" ]; then
        check backup FAIL "no backup has run yet"
    else
        age_h=$(( ( $(date +%s) - $(date -d "${last}" +%s) ) / 3600 ))
        if [ "${result}" != "success" ]; then
            check backup FAIL "last backup ${result} (${age_h}h ago)"
        elif [ "${age_h}" -ge "${BACKUP_MAX_H}" ]; then
            check backup FAIL "last successful backup ${age_h}h ago (limit ${BACKUP_MAX_H}h)"
        else
            check backup OK "last backup ${age_h}h ago"
        fi
    fi
fi

# --- Report changes and save state ---
changes=0
for name in "${!NOW_STATE[@]}"; do
    state="${NOW_STATE[${name}]}"
    prev="$(awk -v k="${name}" '$1 == k {print $2}' "${STATE_FILE}")"
    echo "${name} ${state}" >> "${STATE_FILE}.new"
    if [ "${PRINT}" = true ]; then
        printf '  %-4s  %-24s %s\n' "${state}" "${name}" "${NOW_DETAIL[${name}]}"
        continue
    fi
    if [ "${state}" != "${prev:-OK}" ]; then
        changes=$((changes + 1))
        if [ "${state}" = FAIL ]; then
            "${NOTIFY}" high "${name} failing" "${NOW_DETAIL[${name}]}"
        else
            "${NOTIFY}" default "${name} recovered" "${NOW_DETAIL[${name}]}"
        fi
    fi
done
if [ "${PRINT}" = true ]; then
    rm -f "${STATE_FILE}.new"
else
    mv "${STATE_FILE}.new" "${STATE_FILE}"
    echo "health check: ${#NOW_STATE[@]} checks, ${changes} change(s)"
fi
