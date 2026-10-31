#!/usr/bin/env bash
# Aaru Web App Image Build
# Builds the aaru-web image on GitHub Actions (never on this machine)
# and pins the result by digest in infra/quadlet/openwebui.container.
#
# Flow:
#   1. Takes the commit checked out in web/ (must be clean and pushed).
#   2. Pushes tag aaru-<short sha> to CorpLynx/aaru-web.
#   3. aaru-web's "Aaru image" workflow builds linux/amd64, scans with Trivy,
#      and pushes ghcr.io/corplynx/aaru-web:aaru-<short sha>.
#   4. Waits for the run, then writes Image=ghcr.io/corplynx/aaru-web@sha256:...
#      into the Quadlet unit.
#
# Prerequisites:
#   - gh CLI authenticated with push access to CorpLynx/aaru-web
#   - web/ is a clone of CorpLynx/aaru-web (AARU_WEB_DIR overrides the path)
#   - The commit contains .github/workflows/aaru-image.yaml
#
# Usage:
#   infra/scripts/build-openwebui-image.sh [--no-pin]
#     --no-pin   Build and print the image reference without editing the Quadlet unit

set -euo pipefail

# --- Configuration ---
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WEB_DIR="${AARU_WEB_DIR:-${REPO_ROOT}/web}"
WEB_REPO="${AARU_WEB_REPO:-CorpLynx/aaru-web}"
WORKFLOW="aaru-image.yaml"
# What the pin step rewrites: the KEY= line in PIN_FILE (build-anubis-image.sh overrides both).
PIN_FILE="${AARU_IMAGE_PIN_FILE:-${REPO_ROOT}/infra/quadlet/openwebui.container}"
PIN_KEY="${AARU_IMAGE_PIN_KEY:-Image}"
PIN=true

for arg in "$@"; do
    case "${arg}" in
        --no-pin) PIN=false ;;
        -h|--help) sed -n '2,22p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "ERROR: unknown argument: ${arg}"; exit 1 ;;
    esac
done

WORK_DIR="$(mktemp -d)"
cleanup() {
    rm -rf "${WORK_DIR:?}" 2>/dev/null || true
}
trap cleanup EXIT

echo "=== Aaru Image Build (${WEB_REPO}) ==="

# --- Preflight checks ---
command -v gh >/dev/null 2>&1 || { echo "ERROR: gh CLI not found"; exit 1; }
command -v git >/dev/null 2>&1 || { echo "ERROR: git not found"; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "ERROR: gh is not authenticated (run: gh auth login)"; exit 1; }
[ -d "${WEB_DIR}/.git" ] || [ -f "${WEB_DIR}/.git" ] || { echo "ERROR: ${WEB_DIR} is not a git clone"; exit 1; }

SHA="$(git -C "${WEB_DIR}" rev-parse HEAD)"
SHORT="${SHA:0:12}"
TAG="aaru-${SHORT}"
echo "Repo:      ${WEB_REPO}"
echo "Commit:    ${SHA}"
echo "Tag:       ${TAG}"

if [ -n "$(git -C "${WEB_DIR}" status --porcelain)" ]; then
    echo "ERROR: ${WEB_DIR} has uncommitted changes; the build would not match them"
    exit 1
fi

gh api "repos/${WEB_REPO}/commits/${SHA}" >/dev/null 2>&1 || {
    echo "ERROR: commit ${SHORT} is not on ${WEB_REPO}; push it first"
    exit 1
}

git -C "${WEB_DIR}" cat-file -e "${SHA}:.github/workflows/${WORKFLOW}" 2>/dev/null || {
    echo "ERROR: commit ${SHORT} has no .github/workflows/${WORKFLOW}"
    exit 1
}

# --- Step 1: Push the build tag ---
echo "[1/4] Pushing tag ${TAG}..."
REMOTE_TAG_SHA="$(git -C "${WEB_DIR}" ls-remote origin "refs/tags/${TAG}^{}" "refs/tags/${TAG}" | sort -k2 -r | awk 'NR==1{print $1}')"
if [ -z "${REMOTE_TAG_SHA}" ]; then
    git -C "${WEB_DIR}" tag -f "${TAG}" "${SHA}" >/dev/null
    git -C "${WEB_DIR}" push origin "refs/tags/${TAG}"
    NEW_TAG=true
elif [ "${REMOTE_TAG_SHA}" = "${SHA}" ]; then
    echo "  Tag already on ${WEB_REPO}; reusing its build"
    NEW_TAG=false
else
    echo "ERROR: remote tag ${TAG} points at ${REMOTE_TAG_SHA}, not ${SHA}"
    exit 1
fi

# --- Step 2: Find the workflow run ---
echo "[2/4] Waiting for the workflow run to start..."
RUN_ID=""
for _ in $(seq 1 30); do
    RUN_ID="$(gh run list -R "${WEB_REPO}" --workflow "${WORKFLOW}" --branch "${TAG}" \
        --limit 1 --json databaseId --jq '.[0].databaseId // empty')"
    [ -n "${RUN_ID}" ] && break
    sleep 5
done
if [ -z "${RUN_ID}" ]; then
    echo "ERROR: no '${WORKFLOW}' run appeared for ${TAG} after 150 s"
    [ "${NEW_TAG}" = false ] && echo "  The tag existed before; delete it on the remote to trigger a fresh build."
    exit 1
fi
echo "  Run: https://github.com/${WEB_REPO}/actions/runs/${RUN_ID}"

# --- Step 3: Wait for build, scan and push ---
echo "[3/4] Building on GitHub Actions (typically 20-40 minutes)..."
if ! gh run watch "${RUN_ID}" -R "${WEB_REPO}" --exit-status --interval 30 >/dev/null; then
    echo "ERROR: build failed. A Trivy failure means a fixable CRITICAL/HIGH finding;"
    echo "  fix it or record an exception in aaru-web's .trivyignore."
    echo "  Logs: gh run view ${RUN_ID} -R ${WEB_REPO} --log-failed"
    exit 1
fi

gh run download "${RUN_ID}" -R "${WEB_REPO}" -n aaru-image -D "${WORK_DIR}"
IMAGE_REF="$(tr -d '[:space:]' < "${WORK_DIR}/image-ref.txt")"
case "${IMAGE_REF}" in
    ghcr.io/*@sha256:*) ;;
    *) echo "ERROR: unexpected image reference: ${IMAGE_REF}"; exit 1 ;;
esac
echo "  Image: ${IMAGE_REF}"

# --- Step 4: Pin the Quadlet unit ---
if [ "${PIN}" = true ]; then
    echo "[4/4] Pinning ${PIN_FILE#"${REPO_ROOT}"/}..."
    grep -q "^${PIN_KEY}=" "${PIN_FILE}" || { echo "ERROR: no ${PIN_KEY}= line in ${PIN_FILE}"; exit 1; }
    sed -i.bak "s|^${PIN_KEY}=.*|${PIN_KEY}=${IMAGE_REF}|" "${PIN_FILE}" && rm -f "${PIN_FILE}.bak"
    echo "  Pinned. Review and commit:"
    echo "    git -C ${REPO_ROOT} diff ${PIN_FILE#"${REPO_ROOT}"/}"
else
    echo "[4/4] Skipping Quadlet pin (--no-pin)"
fi

echo "=== Done: ${TAG} ==="
