#!/usr/bin/env bash
# Aaru Anubis Image Build
# Builds the Anubis scanner image on GitHub Actions (CorpLynx/Anubis's
# aaru-image.yaml workflow, Trivy-gated) and pins its digest as ANUBIS_IMAGE in
# infra/config/anubis.conf. fetch-model.sh runs that image to scan new models.
#
# Same flow as build-openwebui-image.sh: the commit checked out in the local
# clone must be clean and pushed; an aaru-<sha> tag triggers the build.
#
# Usage:
#   git clone https://github.com/CorpLynx/Anubis.git anubis   # once, at the repo root (gitignored)
#   infra/scripts/build-anubis-image.sh [--no-pin]
#
# Environment:
#   AARU_ANUBIS_DIR  the local clone (default: <repo>/anubis)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
AARU_WEB_DIR="${AARU_ANUBIS_DIR:-${REPO_ROOT}/anubis}" \
AARU_WEB_REPO="CorpLynx/Anubis" \
AARU_IMAGE_PIN_FILE="${REPO_ROOT}/infra/config/anubis.conf" \
AARU_IMAGE_PIN_KEY="ANUBIS_IMAGE" \
    exec "${REPO_ROOT}/infra/scripts/build-openwebui-image.sh" "$@"
