#!/usr/bin/env bash
# Aaru Model Fetch
# Downloads one Hugging Face model revision into ~/aaru/models/<model-dir>,
# checks every file against the hub's SHA-256, scans it with Anubis, and
# records what was fetched (spec §5: name, exact revision, source, license,
# hashes, scan result).
#
# Anubis is the gate for new models: HIGH or CRITICAL findings (for example a
# chat template carrying hidden instructions or code), or a scan that could not
# finish, move the download to models/.quarantine/ instead of models/, where no
# llama-swap entry points. Review the report there before deciding anything.
#
# The inference containers have no egress, so this is the only way models
# arrive. Run it as the aaru service user on the host, or on another machine
# and copy the directory over (re-run with --verify there).
#
# Usage:
#   infra/scripts/fetch-model.sh <hf-repo> <revision> <model-dir> [--include <glob>]...
#   infra/scripts/fetch-model.sh --verify <model-dir>
#
#   <revision>  a branch, tag or commit. It is resolved to a commit and the
#               commit is recorded, so a moved branch cannot change the files.
#   --include   only files matching the glob, e.g. '*Q4_K_M*.gguf' for one
#               quantization out of a GGUF repo. Repeatable. Default: all files.
#
# Environment:
#   AARU_MODELS_DIR  default ~/aaru/models
#   HF_TOKEN         for gated models; read from the environment, never an argument
#   ANUBIS_BIN       a local `anubis` CLI, used instead of the pinned container
#                    (infra/config/anubis.conf) when fetching off the host
#
# Official sources only: the model author's own org, or ggml-org (the llama.cpp
# project) where the author publishes no GGUF. No community requantizations.
# The catalog in infra/config/models.catalog lists the deployed set;
# infra/scripts/fetch-models.sh fetches all of it.
#
# Examples:
#   infra/scripts/fetch-model.sh ggml-org/gpt-oss-120b-GGUF <commit> gpt-oss-120b --include 'gpt-oss-120b-MXFP4.gguf'
#   infra/scripts/fetch-model.sh Qwen/Qwen3-Embedding-0.6B-GGUF <commit> qwen3-embedding-0.6b --include '*Q8_0.gguf'

set -euo pipefail

MODELS_DIR="${AARU_MODELS_DIR:-${HOME}/aaru/models}"
HF="https://huggingface.co"
MANIFEST=".aaru-model.json"
SCAN_REPORT=".anubis-report.json"
# shellcheck source=../config/anubis.conf
. "$(dirname "${BASH_SOURCE[0]}")/../config/anubis.conf"

for cmd in curl python3 sha256sum; do
    command -v "${cmd}" >/dev/null 2>&1 || { echo "ERROR: ${cmd} not found"; exit 1; }
done

WORK_DIR="$(umask 077; mktemp -d)"
trap 'rm -rf "${WORK_DIR:?}"' EXIT
CURL=(curl -fsSL --retry 3 --proto '=https')
if [ -n "${HF_TOKEN:-}" ]; then
    printf 'Authorization: Bearer %s\n' "${HF_TOKEN}" > "${WORK_DIR}/auth.hdr"
    CURL+=(-H @"${WORK_DIR}/auth.hdr")
fi

# verify <dir> — re-hash every file listed in the manifest
verify() {
    local dir="$1"
    [ -f "${dir}/${MANIFEST}" ] || { echo "ERROR: ${dir}/${MANIFEST} not found"; return 1; }
    python3 - "${dir}" "${MANIFEST}" <<'PY'
import hashlib, json, os, sys
d, name = sys.argv[1], sys.argv[2]
m = json.load(open(os.path.join(d, name)))
bad = 0
for f in m["files"]:
    p = os.path.join(d, f["path"])
    h = hashlib.sha256()
    try:
        with open(p, "rb") as fh:
            for chunk in iter(lambda: fh.read(1 << 20), b""):
                h.update(chunk)
    except FileNotFoundError:
        print("  MISSING  " + f["path"]); bad += 1; continue
    if h.hexdigest() != f["sha256"]:
        print("  MISMATCH " + f["path"]); bad += 1
print("%s@%s: %d files, %s" % (m["repo"], m["commit"][:12], len(m["files"]), "OK" if not bad else "%d bad" % bad))
sys.exit(1 if bad else 0)
PY
}

if [ "${1:-}" = "--verify" ]; then
    verify "${MODELS_DIR}/${2:?--verify needs a model directory}"
    exit $?
fi

REPO="${1:?usage: fetch-model.sh <hf-repo> <revision> <model-dir> [--include <glob>]...}"
REVISION="${2:?missing revision}"
NAME="${3:?missing model directory name}"
shift 3
INCLUDES=()
while [ $# -gt 0 ]; do
    case "$1" in
        --include) INCLUDES+=("${2:?--include needs a glob}"); shift 2 ;;
        *) echo "ERROR: unknown argument: $1"; exit 1 ;;
    esac
done
case "${NAME}" in */*|.*|"") echo "ERROR: model directory must be a plain name"; exit 1 ;; esac

DEST="${MODELS_DIR}/${NAME}"
echo "=== Aaru Model Fetch ==="
echo "Repo:     ${REPO}"
echo "Revision: ${REVISION}"
echo "Into:     ${DEST}"

# Resolve the revision to a commit and list files with their LFS hashes.
"${CURL[@]}" "${HF}/api/models/${REPO}/revision/${REVISION}?blobs=true" > "${WORK_DIR}/info.json"
python3 - "${WORK_DIR}/info.json" "${WORK_DIR}/plan.json" "${INCLUDES[@]+"${INCLUDES[@]}"}" <<'PY'
import fnmatch, json, sys
info = json.load(open(sys.argv[1]))
globs = sys.argv[3:]
files = []
for s in info.get("siblings", []):
    path = s["rfilename"]
    if globs and not any(fnmatch.fnmatch(path, g) for g in globs):
        continue
    if ".." in path.split("/") or path.startswith("/"):
        sys.exit("refusing unsafe path from the hub: " + path)
    lfs = s.get("lfs") or {}
    files.append({"path": path, "size": s.get("size") or lfs.get("size"), "lfs_sha256": lfs.get("sha256")})
if not files:
    sys.exit("no files matched")
card = info.get("cardData") or {}
json.dump({"repo": info["id"], "commit": info["sha"], "license": card.get("license") or "unknown",
           "gated": info.get("gated", False), "files": files}, open(sys.argv[2], "w"))
total = sum(f["size"] or 0 for f in files)
print("Commit:   %s\nLicense:  %s\nFiles:    %d (%.1f GB)" % (info["sha"], card.get("license") or "unknown", len(files), total / 1e9))
PY

COMMIT="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["commit"])' "${WORK_DIR}/plan.json")"
mkdir -p "${DEST}"
# A finished fetch is left read-only; make it writable again to resume or update.
chmod -R u+w "${DEST}"

# Download each file at the resolved commit; LFS files must match the hub's hash.
python3 -c 'import json,sys; [print(f["path"], f["lfs_sha256"] or "-") for f in json.load(open(sys.argv[1]))["files"]]' "${WORK_DIR}/plan.json" \
| while read -r path expected; do
    mkdir -p "$(dirname "${DEST}/${path}")"
    if [ "${expected}" != "-" ] && [ -f "${DEST}/${path}" ] \
        && [ "$(sha256sum "${DEST}/${path}" | cut -d' ' -f1)" = "${expected}" ]; then
        echo "  have     ${path}"
        continue
    fi
    echo "  fetch    ${path}"
    "${CURL[@]}" -o "${DEST}/${path}.part" "${HF}/${REPO}/resolve/${COMMIT}/${path}"
    if [ "${expected}" != "-" ] && [ "$(sha256sum "${DEST}/${path}.part" | cut -d' ' -f1)" != "${expected}" ]; then
        rm -f "${DEST}/${path}.part"
        echo "ERROR: ${path} does not match the hub's SHA-256"
        exit 1
    fi
    mv "${DEST}/${path}.part" "${DEST}/${path}"
done

# --- Anubis gate ---------------------------------------------------------------
# The scanner gets the model read-only, with no network, no capabilities and a
# read-only root: it parses untrusted files.
echo "Scanning with Anubis..."
# shellcheck disable=SC2086  # ANUBIS_SCAN_ARGS is a list of flags
if [ -n "${ANUBIS_BIN:-}" ]; then
    SCANNER="${ANUBIS_BIN} ($("${ANUBIS_BIN}" --version 2>/dev/null || echo unknown version))"
    set +e
    "${ANUBIS_BIN}" scan "${DEST}" --format json ${ANUBIS_SCAN_ARGS} > "${WORK_DIR}/anubis.json"
    scan_rc=$?
    set -e
elif [ -n "${ANUBIS_IMAGE:-}" ]; then
    command -v podman >/dev/null 2>&1 || { echo "ERROR: podman not found (or set ANUBIS_BIN)"; exit 1; }
    SCANNER="${ANUBIS_IMAGE}"
    set +e
    podman run --rm --network none --read-only --cap-drop ALL \
        --security-opt no-new-privileges --userns keep-id:uid=10001,gid=10001 \
        -v "${DEST}:/scan:ro,z" "${ANUBIS_IMAGE}" \
        scan /scan --format json ${ANUBIS_SCAN_ARGS} > "${WORK_DIR}/anubis.json"
    scan_rc=$?
    set -e
else
    echo "ERROR: no scanner. Build the image (infra/scripts/build-anubis-image.sh) or set ANUBIS_BIN."
    echo "       ${DEST} is downloaded but not scanned; nothing should load it."
    exit 1
fi

# Exit 0: passed. 1: findings at or above the threshold, or an incomplete scan. 2: usage error.
python3 - "${WORK_DIR}/anubis.json" <<'PY' || true
import json, sys
try:
    r = json.load(open(sys.argv[1]))
except Exception:
    sys.exit()
s = r.get("summary", {})
print("  complete: %s" % s.get("complete"))
for f in r.get("findings", []):
    print("  %-8s %-14s %s %s" % (str(f.get("severity", "")).upper(), f.get("rule_id", ""), f.get("title", ""),
                                 "(" + f["location"] + ")" if f.get("location") else ""))
PY
case "${scan_rc}" in
    0) echo "  Anubis: passed" ;;
    1)
        QUARANTINE="${MODELS_DIR}/.quarantine/${NAME}-$(date -u +%Y%m%dT%H%M%SZ)"
        mkdir -p "${MODELS_DIR}/.quarantine"
        cp "${WORK_DIR}/anubis.json" "${DEST}/${SCAN_REPORT}"
        mv "${DEST}" "${QUARANTINE}"
        echo "ERROR: Anubis failed this model. It is quarantined, not installed:"
        echo "         ${QUARANTINE}"
        echo "       Report: ${QUARANTINE}/${SCAN_REPORT}"
        exit 1 ;;
    *) echo "ERROR: Anubis could not run (exit ${scan_rc}); ${DEST} is not scanned"; exit 1 ;;
esac
cp "${WORK_DIR}/anubis.json" "${DEST}/${SCAN_REPORT}"

# Record the fetch, with a SHA-256 for every file (small non-LFS files included).
python3 - "${WORK_DIR}/plan.json" "${DEST}" "${MANIFEST}" "${SCANNER}" "${ANUBIS_SCAN_ARGS}" <<'PY'
import datetime, hashlib, json, os, sys
plan, dest, name = json.load(open(sys.argv[1])), sys.argv[2], sys.argv[3]
plan["anubis"] = {"scanner": sys.argv[4], "args": sys.argv[5], "result": "passed",
                  "scanned_at": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")}
for f in plan["files"]:
    h = hashlib.sha256()
    with open(os.path.join(dest, f["path"]), "rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    f["sha256"] = h.hexdigest()
    f.pop("lfs_sha256", None)
plan["source"] = "https://huggingface.co/" + plan["repo"]
plan["fetched_at"] = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
json.dump(plan, open(os.path.join(dest, name), "w"), indent=2)
PY

# Read-only from here on, matching the containers' :ro mount.
chmod -R a-w "${DEST}"
verify "${DEST}"
echo ""
echo "Add it to infra/config/llama-swap/config.yaml (--model /models/${NAME}/<file>)"
echo "or, on the vLLM test host, to vllm.container.d/local.conf. Record the commit,"
echo "license and benchmark results alongside the model choice (spec §5)."
