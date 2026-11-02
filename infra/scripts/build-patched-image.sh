#!/usr/bin/env bash
# Aaru Patched Image Build
# Builds a patched copy of an upstream image from infra/images/<name>/ on
# GitHub Actions (this repo's patched-image.yml workflow: base signature check
# where there is a cosign.pub, Trivy gate, smoke test) and pins its digest
# where the deployment uses it.
#
# Same flow as build-openwebui-image.sh: the commit checked out here must be
# clean and pushed; an image-<name>-<sha> tag triggers the build.
#
# Usage:
#   infra/scripts/build-patched-image.sh <postgres|litellm|vllm> [--no-pin]

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
NAME="${1:-}"
[ -n "${NAME}" ] && [ -f "${REPO_ROOT}/infra/images/${NAME}/Containerfile" ] || {
    echo "Usage: $0 <name> [--no-pin]   (name: one of $(find "${REPO_ROOT}/infra/images" -name Containerfile | awk -F/ '{print $(NF-1)}' | sort | tr '\n' ' '))"
    exit 1
}
shift
case "${NAME}" in
    *-*) echo "ERROR: image names cannot contain '-' (the tag is image-<name>-<sha>)"; exit 1 ;;
esac

AARU_WEB_DIR="${REPO_ROOT}" \
AARU_WEB_REPO="CorpLynx/aaru" \
AARU_IMAGE_WORKFLOW="patched-image.yml" \
AARU_IMAGE_TAG_PREFIX="image-${NAME}-" \
AARU_IMAGE_PIN_FILE="${REPO_ROOT}/infra/quadlet/${NAME}.container" \
AARU_IMAGE_PIN_KEY="Image" \
    exec "${REPO_ROOT}/infra/scripts/build-openwebui-image.sh" "$@"
