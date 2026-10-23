#!/usr/bin/env bash
# Aaru Deployment Verification
# Checks the Phase 1 acceptance criteria and release gates (spec §4a, §8, §9, §11).
# Read-only except for short-lived LiteLLM test keys, which it deletes on exit.
#
# Usage:
#   On the host, as the aaru service user:
#     infra/scripts/verify.sh
#   From another machine (external scan):
#     infra/scripts/verify.sh --outside <host-public-ip> [--api-url https://api.<domain>]
#
# Environment (host mode):
#   AARU_GATEWAY        — LiteLLM base URL (default: http://127.0.0.1:4000)
#   AARU_MODEL          — model alias to test (default: fast)
#   LITELLM_MASTER_KEY  — used to create temporary test keys. If unset, read from
#                         the litellm-master-key Podman secret; key tests are
#                         skipped if neither is available.
#
# Exit status: 0 if no check failed, 1 otherwise. WARN does not fail the run.

# `cond && pass || fail` is safe: pass/fail/warn/skip always return 0.
# shellcheck disable=SC2015

set -uo pipefail

GATEWAY="${AARU_GATEWAY:-http://127.0.0.1:4000}"
MODEL="${AARU_MODEL:-fast}"
OUTSIDE_HOST=""
API_URL=""

while [ $# -gt 0 ]; do
    case "$1" in
        --outside) OUTSIDE_HOST="${2:?--outside needs a host}"; shift 2 ;;
        --api-url) API_URL="${2:?--api-url needs a URL}"; shift 2 ;;
        -h|--help) sed -n '2,20p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "ERROR: unknown argument: $1"; exit 1 ;;
    esac
done

PASS=0; FAIL=0; WARN=0; SKIP=0
pass() { PASS=$((PASS + 1)); printf '  PASS  %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf '  FAIL  %s\n' "$1"; }
warn() { WARN=$((WARN + 1)); printf '  WARN  %s\n' "$1"; }
skip() { SKIP=$((SKIP + 1)); printf '  SKIP  %s\n' "$1"; }
section() { printf '\n[%s]\n' "$1"; }

WORK_DIR="$(umask 077; mktemp -d)"
TEST_KEYS=""
cleanup() {
    if [ -n "${TEST_KEYS}" ] && [ -n "${MASTER_KEY:-}" ]; then
        local keys_json
        keys_json="$(printf '%s\n' ${TEST_KEYS} | python3 -c 'import json,sys; print(json.dumps({"keys": sys.stdin.read().split()}))')"
        printf 'Authorization: Bearer %s\n' "${MASTER_KEY}" > "${WORK_DIR}/master.hdr"
        curl -s -o /dev/null --max-time 10 -X POST "${GATEWAY}/key/delete" \
            -H @"${WORK_DIR}/master.hdr" -H 'Content-Type: application/json' -d "${keys_json}" || true
    fi
    rm -rf "${WORK_DIR:?}" 2>/dev/null || true
}
trap cleanup EXIT

# --- HTTP helper: http <name> <method> <url> [bearer] [json-body] ---
# Writes the body to $WORK_DIR/<name>.body and prints the status code.
# Bearer tokens go through a 0600 header file, never the command line.
http() {
    local name="$1" method="$2" url="$3" bearer="${4:-}" body="${5:-}"
    local args=(-s -o "${WORK_DIR}/${name}.body" -w '%{http_code}' --max-time 120 -X "${method}")
    if [ -n "${bearer}" ]; then
        printf 'Authorization: Bearer %s\n' "${bearer}" > "${WORK_DIR}/${name}.hdr"
        args+=(-H @"${WORK_DIR}/${name}.hdr")
    fi
    [ -n "${body}" ] && args+=(-H 'Content-Type: application/json' -d "${body}")
    curl "${args[@]}" "${url}" 2>/dev/null || echo "000"
}

snippet() { head -c 200 "${WORK_DIR}/$1.body" 2>/dev/null | tr '\n' ' '; }

# ============================================================================
# Outside mode: run from a machine that is not the host
# ============================================================================
if [ -n "${OUTSIDE_HOST}" ]; then
    echo "=== Aaru Verification (outside) ==="
    echo "Target: ${OUTSIDE_HOST}"
    command -v nc >/dev/null 2>&1 || { echo "ERROR: nc not found"; exit 1; }

    section "Exposed ports (release gate: no database or inference port reachable)"
    for port in 5432 8080 8000 4000 3000 8088 11434; do
        if nc -z -w 3 "${OUTSIDE_HOST}" "${port}" >/dev/null 2>&1; then
            fail "port ${port} is reachable from outside"
        else
            pass "port ${port} closed or filtered"
        fi
    done
    if nc -z -w 3 "${OUTSIDE_HOST}" 22 >/dev/null 2>&1; then
        warn "port 22 is reachable; spec §4a wants SSH via Tailscale or a management IP only"
    else
        pass "port 22 closed or filtered"
    fi

    if [ -n "${API_URL}" ]; then
        section "Public API (${API_URL})"
        code="$(http noauth POST "${API_URL}/v1/chat/completions" "" "{\"model\":\"${MODEL}\",\"messages\":[{\"role\":\"user\",\"content\":\"hi\"}]}")"
        [ "${code}" = "401" ] && pass "request without a key rejected (401)" || fail "request without a key returned ${code}"
        code="$(http ui GET "${API_URL}/ui/")"
        case "${code}" in
            200) fail "LiteLLM admin UI is publicly served at /ui/ (keep admin paths private, spec §6)" ;;
            *) pass "admin UI not served publicly (${code})" ;;
        esac
    fi

    printf '\nResult: %d passed, %d failed, %d warnings, %d skipped\n' "${PASS}" "${FAIL}" "${WARN}" "${SKIP}"
    [ "${FAIL}" -eq 0 ]; exit $?
fi

# ============================================================================
# Host mode
# ============================================================================
echo "=== Aaru Verification (host) ==="
echo "User:    $(id -un)"
echo "Gateway: ${GATEWAY}"
echo "Model:   ${MODEL}"

for cmd in podman curl python3 ss; do
    command -v "${cmd}" >/dev/null 2>&1 || { echo "ERROR: ${cmd} not found"; exit 1; }
done

# --- Host ---
section "Host"
[ "$(id -u)" -ne 0 ] && pass "running as non-root user" || fail "running as root; run as the aaru service user"

if command -v getenforce >/dev/null 2>&1; then
    mode="$(getenforce)"
    [ "${mode}" = "Enforcing" ] && pass "SELinux enforcing" || fail "SELinux is ${mode}"
else
    fail "getenforce not found; SELinux state unknown"
fi

if command -v firewall-cmd >/dev/null 2>&1 && [ "$(firewall-cmd --state 2>/dev/null)" = "running" ]; then
    zone="$(firewall-cmd --get-default-zone 2>/dev/null)"
    case "${zone}" in
        drop|block) pass "firewalld running, default zone ${zone}" ;;
        *) fail "firewalld default zone is ${zone}; spec §4a wants drop or block" ;;
    esac
else
    fail "firewalld not running"
fi

[ "$(podman info --format '{{.Host.Security.Rootless}}' 2>/dev/null)" = "true" ] \
    && pass "Podman is rootless" || fail "Podman is not rootless"

# --- Host listeners ---
section "Host listeners"
listeners="$(ss -Htln 2>/dev/null | awk '{print $4}')"
for port in 5432 8080 8000 11434; do
    if printf '%s\n' "${listeners}" | grep -Eq "[:.]${port}\$"; then
        fail "port ${port} is listening on the host (database/inference must stay unpublished)"
    else
        pass "port ${port} not published on the host"
    fi
done
for port in 4000 3000 8088; do
    addrs="$(printf '%s\n' "${listeners}" | grep -E "[:.]${port}\$" || true)"
    if [ -z "${addrs}" ]; then
        skip "port ${port} not listening"
    elif printf '%s\n' "${addrs}" | grep -Evq "^(127\.0\.0\.1|\[::1\]):${port}\$"; then
        fail "port ${port} listens beyond loopback: $(printf '%s ' ${addrs})"
    else
        pass "port ${port} bound to loopback only"
    fi
done

# --- Containers ---
section "Containers"
running="$(podman ps --format '{{.Names}}')"
expect_running() {
    printf '%s\n' "${running}" | grep -qx "$1"
}
for c in postgres litellm openwebui cloudflared; do
    expect_running "${c}" && pass "${c} running" || fail "${c} not running"
done
if expect_running llamacpp || expect_running vllm; then
    pass "an inference server is running ($(printf '%s\n' "${running}" | grep -Ex 'llamacpp|vllm' | tr '\n' ' '))"
else
    fail "no inference server (llamacpp or vllm) running"
fi

for c in ${running}; do
    insp() { podman inspect --format "$1" "${c}" 2>/dev/null; }
    [ "$(insp '{{.HostConfig.Privileged}}')" = "false" ] && pass "${c}: not privileged" || fail "${c}: privileged"
    [ "$(insp '{{.HostConfig.NetworkMode}}')" = "host" ] && fail "${c}: host network" || pass "${c}: no host network"
    podman inspect "${c}" 2>/dev/null | grep -q 'no-new-privileges' \
        && pass "${c}: NoNewPrivileges" || fail "${c}: NoNewPrivileges not set"
    [ "$(insp '{{.HostConfig.Memory}}')" != "0" ] && pass "${c}: memory limit set" || fail "${c}: no memory limit"
    case "$(insp '{{.ProcessLabel}}')" in
        *container_t*) pass "${c}: SELinux container_t" ;;
        *) fail "${c}: not confined as container_t" ;;
    esac
    [ "$(insp '{{.HostConfig.ReadonlyRootfs}}')" = "true" ] \
        && pass "${c}: read-only root filesystem" || warn "${c}: writable root filesystem (spec §4a: ReadOnly where supported)"
    caps="$(insp '{{range .EffectiveCaps}}{{.}} {{end}}')"
    [ -z "${caps}" ] && pass "${c}: all capabilities dropped" || warn "${c}: capabilities ${caps}(spec §4a: drop ALL, add only required)"
    case "$(insp '{{.ImageName}}')" in
        *@sha256:*) pass "${c}: image pinned by digest" ;;
        *) warn "${c}: image not pinned by digest ($(insp '{{.ImageName}}'))" ;;
    esac
    if insp '{{range .Mounts}}{{.Source}} {{end}}' | grep -Eq '(podman|docker)\.sock'; then
        [ "${c}" = "dozzle" ] && pass "${c}: Podman socket (expected; admin network only)" \
            || fail "${c}: Podman socket mounted into an application container"
    fi
done

# --- Network segmentation ---
section "Network segmentation"
nets_of() { podman inspect --format '{{range $k, $v := .NetworkSettings.Networks}}{{$k}} {{end}}' "$1" 2>/dev/null | xargs; }
check_nets() {
    local c="$1" want="$2" got
    expect_running "${c}" || { skip "${c}: not running"; return; }
    got="$(nets_of "${c}")"
    [ "${got}" = "${want}" ] && pass "${c}: networks = ${want}" || fail "${c}: networks = ${got:-none}, expected ${want}"
}
check_nets cloudflared "aaru-ingress"
check_nets postgres "aaru-internal"
check_nets llamacpp "aaru-internal"
check_nets vllm "aaru-internal"
check_nets litellm "aaru-ingress aaru-internal"
check_nets openwebui "aaru-ingress aaru-internal"
check_nets dozzle "aaru-admin"

[ "$(podman network inspect aaru-internal --format '{{.Internal}}' 2>/dev/null)" = "true" ] \
    && pass "aaru-internal is an internal network" || fail "aaru-internal is not internal"
# With DNS on, netavark gives the bridge a routable gateway and ingress containers
# can reach internal members by IP (see aaru-internal.network).
[ "$(podman network inspect aaru-internal --format '{{.DNSEnabled}}' 2>/dev/null)" = "false" ] \
    && pass "aaru-internal has DNS disabled (no routable gateway)" || fail "aaru-internal has DNS enabled"

# Probe from throwaway containers using the already-pulled postgres image
# (busybox wget and timeout, bash /dev/tcp), so no extra image is downloaded.
PROBE_IMAGE="$(podman inspect --format '{{.ImageName}}' postgres 2>/dev/null)"
if [ -n "${PROBE_IMAGE}" ]; then
    probe() { podman run --rm --network "$1" --entrypoint "$2" "${PROBE_IMAGE}" "${@:3}" >/dev/null 2>&1; }

    probe aaru-internal wget -q -T 5 -O /dev/null http://1.1.1.1 \
        && fail "aaru-internal has outbound internet (inference egress)" \
        || pass "aaru-internal has no outbound internet"
    probe aaru-ingress wget -q -T 5 -O /dev/null http://1.1.1.1 \
        && pass "aaru-ingress has outbound internet (cloudflared can reach Cloudflare)" \
        || fail "aaru-ingress has no outbound internet; cloudflared cannot connect"

    probe aaru-ingress pg_isready -h postgres -p 5432 -t 3 \
        && fail "postgres reachable by name from the ingress network" \
        || pass "postgres not reachable by name from the ingress network"

    # Where cloudflared sits: an ingress-only container must not open TCP to
    # the database or the unauthenticated inference ports.
    for target in postgres:5432 llamacpp:8080 vllm:8000; do
        c="${target%%:*}"; port="${target##*:}"
        expect_running "${c}" || continue
        ip="$(podman inspect --format '{{(index .NetworkSettings.Networks "aaru-internal").IPAddress}}' "${c}" 2>/dev/null)"
        [ -n "${ip}" ] || { fail "${c}: no aaru-internal address"; continue; }
        probe aaru-ingress timeout 4 bash -c "exec 3<>/dev/tcp/${ip}/${port}" \
            && fail "${c} (${ip}:${port}) reachable by IP from the ingress network" \
            || pass "${c} not reachable by IP from the ingress network"
    done
else
    skip "egress and isolation probes (postgres container not found)"
fi

# --- Database roles ---
section "Database roles"
if expect_running postgres; then
    roles="$(podman exec postgres sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tA -c "select rolname from pg_roles where rolname in ('"'litellm','openwebui'"') and not rolsuper and not rolcreatedb and not rolcreaterole order by 1"' 2>/dev/null | xargs)"
    [ "${roles}" = "litellm openwebui" ] && pass "separate least-privilege roles for litellm and openwebui" \
        || fail "expected non-superuser roles litellm and openwebui, found: ${roles:-none}"
    public_connect="$(podman exec postgres sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tA -c "select datname from pg_database where datname in ('"'litellm','openwebui'"') and has_database_privilege('"'public'"', datname, '"'CONNECT'"')"' 2>/dev/null | xargs)"
    [ -z "${public_connect}" ] && pass "PUBLIC cannot connect to service databases" \
        || fail "PUBLIC can connect to: ${public_connect}"
else
    skip "postgres not running"
fi

# --- Gateway ---
section "Gateway (${GATEWAY})"
CANARY="aaru-verify-canary-$(date +%s)-$$"
CHAT_BODY="{\"model\":\"${MODEL}\",\"max_tokens\":8,\"messages\":[{\"role\":\"user\",\"content\":\"Reply with one word. ${CANARY}\"}]}"
STREAM_BODY="{\"model\":\"${MODEL}\",\"max_tokens\":8,\"stream\":true,\"messages\":[{\"role\":\"user\",\"content\":\"Reply with one word. ${CANARY}\"}]}"
KEY_OK=""

code="$(http live GET "${GATEWAY}/health/liveliness")"
if [ "${code}" != "200" ]; then
    fail "LiteLLM not reachable (${code}); skipping gateway checks"
else
    pass "LiteLLM reachable"

    code="$(http nokey POST "${GATEWAY}/v1/chat/completions" "" "${CHAT_BODY}")"
    [ "${code}" = "401" ] && pass "request without a key rejected (401)" || fail "request without a key returned ${code}"
    code="$(http badkey POST "${GATEWAY}/v1/chat/completions" "sk-aaru-verify-invalid" "${CHAT_BODY}")"
    [ "${code}" = "401" ] && pass "invalid key rejected (401)" || fail "invalid key returned ${code}"

    MASTER_KEY="${LITELLM_MASTER_KEY:-}"
    if [ -z "${MASTER_KEY}" ]; then
        MASTER_KEY="$(podman secret inspect --showsecret --format '{{.SecretData}}' litellm-master-key 2>/dev/null || true)"
    fi

    if [ -z "${MASTER_KEY}" ]; then
        skip "key enforcement tests (no LITELLM_MASTER_KEY and the Podman secret is unreadable)"
    else
        # gen_key <name> <json> — creates a 15-minute test key, prints it
        gen_key() {
            local code
            code="$(http "$1" POST "${GATEWAY}/key/generate" "${MASTER_KEY}" "$2")"
            [ "${code}" = "200" ] || return 1
            python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["key"])' "${WORK_DIR}/$1.body"
        }
        KEY_OK="$(gen_key gen_ok "{\"models\":[\"${MODEL}\"],\"duration\":\"15m\",\"key_alias\":\"aaru-verify-ok-$$\"}")"
        KEY_DENY="$(gen_key gen_deny "{\"models\":[\"aaru-verify-no-such-alias\"],\"duration\":\"15m\",\"key_alias\":\"aaru-verify-deny-$$\"}")"
        KEY_RPM="$(gen_key gen_rpm "{\"models\":[\"${MODEL}\"],\"rpm_limit\":1,\"duration\":\"15m\",\"key_alias\":\"aaru-verify-rpm-$$\"}")"
        TEST_KEYS="${KEY_OK} ${KEY_DENY} ${KEY_RPM}"

        if [ -z "${KEY_OK}" ] || [ -z "${KEY_DENY}" ] || [ -z "${KEY_RPM}" ]; then
            fail "could not create test keys with the master key: $(snippet gen_ok)"
        else
            pass "created temporary test keys (deleted on exit)"

            code="$(http ok POST "${GATEWAY}/v1/chat/completions" "${KEY_OK}" "${CHAT_BODY}")"
            if [ "${code}" = "200" ] && grep -q '"choices"' "${WORK_DIR}/ok.body"; then
                pass "valid key gets a completion from '${MODEL}'"
            else
                fail "valid key on '${MODEL}' returned ${code}: $(snippet ok)"
            fi

            code="$(http stream POST "${GATEWAY}/v1/chat/completions" "${KEY_OK}" "${STREAM_BODY}")"
            if [ "${code}" = "200" ] && grep -q '^data:' "${WORK_DIR}/stream.body" && grep -q '\[DONE\]' "${WORK_DIR}/stream.body"; then
                pass "streaming (SSE) works end to end on the gateway"
            else
                fail "streaming returned ${code}: $(snippet stream)"
            fi

            code="$(http deny POST "${GATEWAY}/v1/chat/completions" "${KEY_DENY}" "${CHAT_BODY}")"
            case "${code}" in
                401|403) pass "key without '${MODEL}' in its allowlist is rejected (${code})" ;;
                200) fail "key without '${MODEL}' in its allowlist got a completion" ;;
                *) warn "allowlist check returned ${code} (expected 401/403): $(snippet deny)" ;;
            esac

            code="$(http admin GET "${GATEWAY}/key/list" "${KEY_OK}")"
            [ "${code}" = "200" ] && fail "a virtual key can list keys (admin route)" \
                || pass "virtual key cannot use admin routes (${code})"

            got_429=false
            for i in 1 2 3; do
                code="$(http "rpm${i}" POST "${GATEWAY}/v1/chat/completions" "${KEY_RPM}" "${CHAT_BODY}")"
                [ "${code}" = "429" ] && got_429=true
            done
            "${got_429}" && pass "rpm_limit=1 enforced (429 on burst)" || fail "rpm_limit=1 not enforced: 3 requests, no 429"
        fi
    fi
fi

# --- Logs ---
section "Logs (no prompt text or keys)"
if [ -n "${KEY_OK}" ]; then
    for c in litellm llamacpp vllm openwebui cloudflared; do
        expect_running "${c}" || continue
        log="$(podman logs --since 15m "${c}" 2>&1)"
        if printf '%s' "${log}" | grep -qF "${CANARY}"; then
            fail "${c}: prompt text appears in container logs"
        else
            pass "${c}: no prompt text in logs"
        fi
        if printf '%s' "${log}" | grep -qF "${KEY_OK}"; then
            fail "${c}: API key appears in container logs"
        else
            pass "${c}: no API key in logs"
        fi
    done
else
    skip "log checks need a successful test request"
fi

# --- Operations ---
section "Operations"
systemctl --user is-enabled aaru-backup.timer >/dev/null 2>&1 \
    && pass "backup timer enabled" || warn "aaru-backup.timer not enabled"

printf '\nResult: %d passed, %d failed, %d warnings, %d skipped\n' "${PASS}" "${FAIL}" "${WARN}" "${SKIP}"
echo "Also run from another machine: infra/scripts/verify.sh --outside <public-ip> --api-url https://api.<domain>"
[ "${FAIL}" -eq 0 ]
