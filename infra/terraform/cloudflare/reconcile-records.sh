#!/usr/bin/env bash
# Import DNS records that exist in Cloudflare but are not tracked in Terraform
# state, and optionally delete records that are in the zone but that this stack
# no longer owns.
#
# Use after an apply that aborted partway. When an apply fails, Terraform
# cancels the record creations that were still in flight, but Cloudflare may
# have completed them server-side. Those records then exist in the zone
# without being in state, and the next apply fails with:
#
#   81058  An identical record already exists.
#   81053  An A, AAAA, or CNAME record with that host already exists.
#
# Importing them hands them back to Terraform instead of deleting and
# recreating them, which keeps the record IDs stable.
#
# Prerequisites:
#   - CLOUDFLARE_API_TOKEN in the environment, or ~/.aaru-cloudflare-token
#   - Terraform, in this directory, state initialised
#
# Usage:
#   ./reconcile-records.sh                  # list what would be imported or pruned
#   ./reconcile-records.sh --apply          # import the orphans
#   ./reconcile-records.sh --prune          # delete the records this stack dropped
#   ./reconcile-records.sh --apply --prune  # both

set -euo pipefail

STACK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOKEN_FILE="${CLOUDFLARE_TOKEN_FILE:-${HOME}/.aaru-cloudflare-token}"
APPLY=0
PRUNE=0
ASSUME_YES=0
for arg in "$@"; do
    case "${arg}" in
        --apply) APPLY=1 ;;
        --prune) PRUNE=1 ;;
        --yes) ASSUME_YES=1 ;;
        *) echo "unknown argument: ${arg}"; exit 2 ;;
    esac
done

cd "${STACK_DIR}"

# --- Token ---
if [ -z "${CLOUDFLARE_API_TOKEN:-}" ]; then
    if [ -r "${TOKEN_FILE}" ]; then
        CLOUDFLARE_API_TOKEN="$(cat "${TOKEN_FILE}")"
    else
        echo "ERROR: no API token. Export CLOUDFLARE_API_TOKEN or create ${TOKEN_FILE}."
        exit 1
    fi
fi
# The provider reads CLOUDFLARE_API_TOKEN from the environment, so it has to
# be exported for terraform to inherit it.
export CLOUDFLARE_API_TOKEN

if ! command -v terraform >/dev/null 2>&1; then
    echo "ERROR: terraform not found"
    exit 1
fi

WORK="$(mktemp -d -t aaru-reconcile)"
trap 'rm -rf "${WORK}"' EXIT

# --- Plan, so we know which records this stack is supposed to own ---
echo "=== Building plan ==="
terraform plan -input=false -out="${WORK}/plan.tfplan" >/dev/null
terraform show -json "${WORK}/plan.tfplan" > "${WORK}/plan.json"
terraform show -json > "${WORK}/state.json"

ZONE_ID="$(python3 -c '
import json, sys
for r in json.load(open(sys.argv[1])).get("values", {}).get("root_module", {}).get("resources", []):
    if r.get("type") == "cloudflare_zone":
        print((r.get("values") or {}).get("id", ""))
        break
' "${WORK}/state.json")"

if [ -z "${ZONE_ID}" ]; then
    echo "ERROR: could not find the zone id in the state"
    exit 1
fi

# --- Records currently in the zone ---
echo "=== Fetching records from Cloudflare ==="
curl -sS --fail-with-body \
    -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
    -H "Content-Type: application/json" \
    "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records?per_page=100" \
    > "${WORK}/records.json"

# --- Classify them ---
REPORT="$(python3 "${STACK_DIR}/reconcile-records.py" \
    "${WORK}/plan.json" "${WORK}/state.json" "${WORK}/records.json" "${ZONE_ID}")"

show_nameservers() {
    echo ""
    echo "Zone nameservers (for Lightsail -> Edit Name Servers):"
    terraform output -json zone_name_servers 2>/dev/null \
        | python3 -c 'import json,sys; [print("   ", n) for n in json.load(sys.stdin)]' || true
}

if [ "${REPORT}" = "NONE" ]; then
    echo ""
    echo "Nothing to reconcile — state, the plan, and the zone agree."
    show_nameservers
    exit 0
fi

IMPORTS="$(printf '%s\n' "${REPORT}" | grep '^IMPORT' || true)"
DELETES="$(printf '%s\n' "${REPORT}" | grep -E '^(PRUNE|DUPLICATE)' || true)"

if [ -n "${IMPORTS}" ]; then
    echo ""
    echo "=== Orphan records to import (ours, but the create was orphaned) ==="
    printf '%s\n' "${IMPORTS}" | while IFS=$'\t' read -r _ addr zone rec rtype name content; do
        echo "  ${addr}"
        echo "      ${zone}/${rec}"
    done
fi

if [ -n "${DELETES}" ]; then
    echo ""
    echo "=== Records in the zone that should not be there ==="
    printf '%s\n' "${DELETES}" | while IFS=$'\t' read -r _ rec rtype name content; do
        echo "  ${rtype} ${name} -> ${content}"
        echo "      ${rec}"
    done
    echo ""
    echo "  These are either records this stack dropped from its configuration,"
    echo "  or stale copies left behind by the DNS scan Cloudflare ran when the"
    echo "  zone was created. They are not in Terraform state, so Terraform will"
    echo "  not touch them — they stay in the zone until something removes them."
fi

if [ "${APPLY}" -eq 0 ] && [ "${PRUNE}" -eq 0 ]; then
    echo ""
    echo "Re-run with --apply to import, or --prune to delete the unowned ones."
    show_nameservers
    exit 0
fi

if [ -n "${IMPORTS}" ] && [ "${APPLY}" -eq 1 ]; then
    echo ""
    echo "=== Importing ==="
    printf '%s\n' "${IMPORTS}" | while IFS=$'\t' read -r _ addr zone rec rtype name content; do
        printf '  %s ... ' "${addr}"
        if terraform import "${addr}" "${zone}/${rec}" >/dev/null 2>&1; then
            echo "ok"
        else
            echo "FAILED"
        fi
    done
fi

if [ -n "${DELETES}" ] && [ "${PRUNE}" -eq 1 ]; then
    echo ""
    if [ "${ASSUME_YES}" -eq 0 ]; then
        echo "The following records will be DELETED from the zone:"
        printf '%s\n' "${DELETES}" | while IFS=$'\t' read -r _ rec rtype name content; do
            echo "  ${rtype} ${name} -> ${content}"
        done
        echo ""
        printf 'Type "yes" to delete them: '
        read -r reply
        [ "${reply}" = "yes" ] || { echo "Aborted."; exit 1; }
    fi

    echo ""
    echo "=== Deleting ==="
    printf '%s\n' "${DELETES}" | while IFS=$'\t' read -r _ rec rtype name content; do
        printf '  %s %s ... ' "${rtype}" "${name}"
        code=$(curl -sS -o /dev/null -w '%{http_code}' -X DELETE \
            -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
            "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records/${rec}")
        if [ "${code}" = "200" ]; then
            echo "deleted"
        else
            echo "FAILED (HTTP ${code})"
        fi
    done
fi

echo ""
echo "=== Re-planning ==="
terraform plan -input=false -no-color 2>&1 | grep -E '^(Plan:|Error)' || true
show_nameservers
