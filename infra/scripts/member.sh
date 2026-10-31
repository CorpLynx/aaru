#!/usr/bin/env bash
# Aaru Member Keys
# Operator-run provisioning of LiteLLM virtual keys (spec §6). Membership is
# invite-only: one key per member, the same allowlist and limits by default,
# narrowed per key when needed. Run on the host as the aaru service user.
#
# Usage:
#   infra/scripts/member.sh add <member> --terms-accepted <YYYY-MM-DD> [--models fast,dense,...] [--rpm N] [--tpm N] [--parallel N] [--days N]
#   infra/scripts/member.sh list
#   infra/scripts/member.sh rotate <member>     new key with the same settings, old keys deleted
#   infra/scripts/member.sh revoke <member>     delete every key the member has
#   infra/scripts/member.sh webapp-key          (re)create the web app's key and store it
#                                               in the openai-api-key Podman secret
#
#   --terms-accepted is the date the member agreed to the Terms, Acceptable Use
#   Policy and Privacy Notice (keep their written agreement, e.g. the email). It
#   and the current TERMS_VERSION from legal/legal.conf are stored on the key,
#   so every key records which version its holder accepted.
#
#   <member> is the member's email address; it becomes the LiteLLM user_id
#   and the key alias "member:<member>". New keys are printed once and never
#   stored by this script: hand them to the member over a private channel.
#
# Defaults (override in the environment):
#   AARU_GATEWAY            http://127.0.0.1:4000
#   AARU_MEMBER_MODELS      fast,dense,reasoning,embed,embed-small
#   AARU_MEMBER_RPM         30        requests per minute
#   AARU_MEMBER_TPM         100000    tokens per minute
#   AARU_MEMBER_PARALLEL    2         concurrent requests
#   AARU_MEMBER_DAYS        365       key lifetime; 0 for no expiry
#   LITELLM_MASTER_KEY      read from the litellm-master-key Podman secret if unset

set -euo pipefail

GATEWAY="${AARU_GATEWAY:-http://127.0.0.1:4000}"
MODELS="${AARU_MEMBER_MODELS:-fast,dense,reasoning,embed,embed-small}"
RPM="${AARU_MEMBER_RPM:-30}"
TPM="${AARU_MEMBER_TPM:-100000}"
PARALLEL="${AARU_MEMBER_PARALLEL:-2}"
DAYS="${AARU_MEMBER_DAYS:-365}"

usage() { sed -n '2,31p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; }

for cmd in curl python3; do
    command -v "${cmd}" >/dev/null 2>&1 || { echo "ERROR: ${cmd} not found"; exit 1; }
done

WORK_DIR="$(umask 077; mktemp -d)"
trap 'rm -rf "${WORK_DIR:?}"' EXIT

MASTER_KEY="${LITELLM_MASTER_KEY:-}"
if [ -z "${MASTER_KEY}" ]; then
    MASTER_KEY="$(podman secret inspect --showsecret --format '{{.SecretData}}' litellm-master-key 2>/dev/null || true)"
fi
[ -n "${MASTER_KEY}" ] || { echo "ERROR: no LITELLM_MASTER_KEY and the litellm-master-key secret is unreadable"; exit 1; }
# The master key goes through a 0600 header file, never the command line.
printf 'Authorization: Bearer %s\n' "${MASTER_KEY}" > "${WORK_DIR}/auth.hdr"

# api <method> <path> [json-body] — prints the response body; fails on non-2xx
api() {
    local args=(-sS -o "${WORK_DIR}/body" -w '%{http_code}' --max-time 30 -X "$1" -H @"${WORK_DIR}/auth.hdr")
    [ -n "${3:-}" ] && args+=(-H 'Content-Type: application/json' --data-binary "$3")
    local code
    code="$(curl "${args[@]}" "${GATEWAY}$2")" || { echo "ERROR: cannot reach LiteLLM at ${GATEWAY}" >&2; return 1; }
    case "${code}" in
        2??) cat "${WORK_DIR}/body" ;;
        *) echo "ERROR: $1 $2 returned ${code}: $(head -c 300 "${WORK_DIR}/body")" >&2; return 1 ;;
    esac
}

# keys_of <alias> — the key tokens (hashed ids) carrying that alias
keys_of() {
    api GET "/key/list?return_full_object=true&size=1000" | python3 -c '
import json, sys
alias = sys.argv[1]
for k in json.load(sys.stdin).get("keys", []):
    if isinstance(k, dict) and k.get("key_alias") == alias:
        print(k.get("token") or k.get("key"))
' "$1"
}

# generate <alias> <user_id> <models-csv> <rpm> <tpm> <parallel> <days> <metadata-json>
generate() {
    local body
    body="$(python3 -c '
import json, sys
alias, user, models, rpm, tpm, par, days, meta = sys.argv[1:]
b = {"key_alias": alias, "user_id": user, "models": [m for m in models.split(",") if m],
     "rpm_limit": int(rpm), "tpm_limit": int(tpm), "max_parallel_requests": int(par),
     "metadata": json.loads(meta)}
if int(days) > 0:
    b["duration"] = "%dd" % int(days)
print(json.dumps(b))
' "$@")"
    api POST /key/generate "${body}" | python3 -c 'import json,sys; print(json.load(sys.stdin)["key"])'
}

delete_keys() {
    [ $# -gt 0 ] || return 0
    api POST /key/delete "$(python3 -c 'import json,sys; print(json.dumps({"keys": sys.argv[1:]}))' "$@")" >/dev/null
}

cmd="${1:-}"; shift || true
case "${cmd}" in
    add)
        MEMBER="${1:?usage: member.sh add <member> [options]}"; shift
        while [ $# -gt 0 ]; do
            case "$1" in
                --terms-accepted) ACCEPTED="${2:?}"; shift 2 ;;
                --models) MODELS="${2:?}"; shift 2 ;;
                --rpm) RPM="${2:?}"; shift 2 ;;
                --tpm) TPM="${2:?}"; shift 2 ;;
                --parallel) PARALLEL="${2:?}"; shift 2 ;;
                --days) DAYS="${2:?}"; shift 2 ;;
                *) echo "ERROR: unknown option: $1"; exit 1 ;;
            esac
        done
        [[ "${ACCEPTED:-}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] \
            || { echo "ERROR: --terms-accepted <YYYY-MM-DD> is required: no key without a recorded agreement"; exit 1; }
        LEGAL_CONF="$(dirname "${BASH_SOURCE[0]}")/../../legal/legal.conf"
        TERMS_VERSION="$(sed -n 's/^TERMS_VERSION="\{0,1\}\([^"]*\)"\{0,1\}$/\1/p' "${LEGAL_CONF}" 2>/dev/null)"
        [ -n "${TERMS_VERSION}" ] || { echo "ERROR: no TERMS_VERSION in legal/legal.conf (copy legal.conf.example)"; exit 1; }
        [ -z "$(keys_of "member:${MEMBER}")" ] || { echo "ERROR: ${MEMBER} already has a key; use rotate"; exit 1; }
        KEY="$(generate "member:${MEMBER}" "${MEMBER}" "${MODELS}" "${RPM}" "${TPM}" "${PARALLEL}" "${DAYS}" \
            "{\"added\": \"$(date -u +%Y-%m-%d)\", \"terms_version\": \"${TERMS_VERSION}\", \"terms_accepted\": \"${ACCEPTED}\"}")"
        echo "Key for ${MEMBER} (models ${MODELS}; ${RPM} rpm, ${TPM} tpm, ${PARALLEL} parallel):"
        echo "  ${KEY}"
        echo "Shown once. Send it over a private channel."
        if systemctl --user is-active tailscale.service >/dev/null 2>&1; then
            echo "Access is over Tailscale for now: share the aaru node with them"
            echo "(admin console > Machines > aaru > Share; see infra/terraform/tailscale/README.md)."
        fi
        ;;
    list)
        api GET "/key/list?return_full_object=true&size=1000" | python3 -c '
import json, sys
rows = [k for k in json.load(sys.stdin).get("keys", []) if isinstance(k, dict)]
print("%-40s %-14s %6s %8s %4s  %-10s %s" % ("ALIAS", "MODELS", "RPM", "TPM", "PAR", "EXPIRES", "SPEND"))
for k in sorted(rows, key=lambda k: k.get("key_alias") or ""):
    print("%-40s %-14s %6s %8s %4s  %-10s %.4f" % (
        (k.get("key_alias") or "-")[:40], ",".join(k.get("models") or ["all"])[:14],
        k.get("rpm_limit") or "-", k.get("tpm_limit") or "-", k.get("max_parallel_requests") or "-",
        (k.get("expires") or "never")[:10], k.get("spend") or 0))
'
        ;;
    rotate)
        MEMBER="${1:?usage: member.sh rotate <member>}"
        mapfile -t OLD < <(keys_of "member:${MEMBER}")
        [ "${#OLD[@]}" -gt 0 ] || { echo "ERROR: ${MEMBER} has no key"; exit 1; }
        # Carry the existing settings over to the new key.
        read -r MODELS RPM TPM PARALLEL < <(api GET "/key/info?key=${OLD[0]}" | python3 -c '
import json, sys
i = json.load(sys.stdin).get("info", {})
print(",".join(i.get("models") or []) or "fast", i.get("rpm_limit") or 30, i.get("tpm_limit") or 100000, i.get("max_parallel_requests") or 2)')
        KEY="$(generate "member:${MEMBER}" "${MEMBER}" "${MODELS}" "${RPM}" "${TPM}" "${PARALLEL}" "${DAYS}" \
            "{\"rotated\": \"$(date -u +%Y-%m-%d)\"}")"
        delete_keys "${OLD[@]}"
        echo "New key for ${MEMBER}; ${#OLD[@]} old key(s) deleted:"
        echo "  ${KEY}"
        ;;
    revoke)
        MEMBER="${1:?usage: member.sh revoke <member>}"
        mapfile -t OLD < <(keys_of "member:${MEMBER}")
        [ "${#OLD[@]}" -gt 0 ] || { echo "${MEMBER} has no keys"; exit 0; }
        delete_keys "${OLD[@]}"
        echo "Revoked ${#OLD[@]} key(s) for ${MEMBER}. Remove their web app account separately."
        ;;
    webapp-key)
        # The web app's own key: it calls LiteLLM for every signed-in member, so it gets
        # the sum of what members need, no expiry, and never the master key (spec §2).
        mapfile -t OLD < <(keys_of "service:openwebui")
        KEY="$(generate "service:openwebui" "service:openwebui" "${MODELS}" "$((RPM * 10))" "$((TPM * 10))" "$((PARALLEL * 4))" 0 \
            "{\"service\": \"openwebui\"}")"
        printf '%s' "${KEY}" | podman secret create --replace openai-api-key - >/dev/null
        delete_keys "${OLD[@]+"${OLD[@]}"}"
        echo "Web app key stored in the openai-api-key secret; ${#OLD[@]} old key(s) deleted."
        echo "Restart the web app to pick it up: systemctl --user restart openwebui.service"
        ;;
    -h|--help|"") usage ;;
    *) echo "ERROR: unknown command: ${cmd}"; usage; exit 1 ;;
esac
