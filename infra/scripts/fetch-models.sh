#!/usr/bin/env bash
# Aaru Model Catalog Fetch
# Fetches every model in infra/config/models.catalog through fetch-model.sh,
# so each one is pinned, hash-checked and scanned by Anubis. Models already
# fetched are verified and skipped; a model that fails stops the run.
#
# Usage:
#   infra/scripts/fetch-models.sh                  # the whole catalog
#   infra/scripts/fetch-models.sh <model-dir>...   # only these entries

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CATALOG="${SCRIPT_DIR}/../config/models.catalog"
MODELS_DIR="${AARU_MODELS_DIR:-${HOME}/aaru/models}"
WANT=("$@")

found=0
while read -r name repo commit files; do
    case "${name}" in ""|\#*) continue ;; esac
    if [ "${#WANT[@]}" -gt 0 ] && ! printf '%s\n' "${WANT[@]}" | grep -qxF "${name}"; then
        continue
    fi
    found=$((found + 1))
    echo ""
    echo "=== ${name} (${repo}@${commit:0:12}) ==="
    if [ -f "${MODELS_DIR}/${name}/.aaru-model.json" ] \
        && grep -q "\"commit\": \"${commit}\"" "${MODELS_DIR}/${name}/.aaru-model.json" \
        && "${SCRIPT_DIR}/fetch-model.sh" --verify "${name}"; then
        echo "  already fetched and verified"
        continue
    fi
    includes=()
    IFS=',' read -r -a list <<< "${files}"
    for f in "${list[@]}"; do includes+=(--include "${f}"); done
    "${SCRIPT_DIR}/fetch-model.sh" "${repo}" "${commit}" "${name}" "${includes[@]}"
done < "${CATALOG}"

if [ "${#WANT[@]}" -gt 0 ] && [ "${found}" -ne "${#WANT[@]}" ]; then
    echo "ERROR: not every requested model is in ${CATALOG}"
    exit 1
fi
echo ""
echo "Catalog fetched. llama-swap entries: infra/config/llama-swap/config.yaml"
