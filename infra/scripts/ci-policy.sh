#!/usr/bin/env bash
# Aaru Repository Policy Checks
# Rules gitleaks cannot express, run by CI on every push and by the pre-commit
# hook on what is staged. Each failure names the file and the rule.
#
#   1. No secret-bearing or host-specific files are tracked (state, tfvars,
#      backend config, legal.conf, local drop-ins, keys, .env files).
#   2. Every container image is pinned by digest; no floating tags.
#   3. Every GitHub Action is pinned to a full commit SHA.
#   4. Models come only from official sources, pinned to a commit.
#   5. Scripts are executable.
#
# Usage: infra/scripts/ci-policy.sh [--staged]
#   --staged  check the git index (what the next commit will contain) rather
#             than all tracked files; used by .githooks/pre-commit.

set -euo pipefail

cd "$(git rev-parse --show-toplevel)"
STAGED=false
[ "${1:-}" = "--staged" ] && STAGED=true

# Plain read loops rather than mapfile: this also runs in the pre-commit hook
# on macOS, whose /bin/bash is 3.2.
FILES=()
if [ "${STAGED}" = true ]; then
    # Added, copied, modified or renamed files in the index.
    while IFS= read -r f; do FILES+=("${f}"); done < <(git diff --cached --name-only --diff-filter=ACMR)
else
    while IFS= read -r f; do FILES+=("${f}"); done < <(git ls-files)
fi
[ "${#FILES[@]}" -gt 0 ] || { echo "policy: nothing to check"; exit 0; }

FAIL=0
fail() { FAIL=$((FAIL + 1)); printf 'FAIL  %s\n' "$1"; }

# Contents as they will be committed: the index when staged, else the tree.
content() {
    if [ "${STAGED}" = true ]; then git show ":$1" 2>/dev/null; else cat "$1" 2>/dev/null; fi
}

# --- 1. Forbidden files ------------------------------------------------------
for f in "${FILES[@]}"; do
    case "${f}" in
        *.tfstate|*.tfstate.*|*.tfplan|*/terraform.tfvars|terraform.tfvars|*.auto.tfvars|*/backend.hcl|backend.hcl|*/.terraform/*)
            fail "${f}: Terraform state, variables or backend config must not be committed" ;;
        legal/legal.conf|legal/site/*)
            fail "${f}: operator details and rendered legal pages are per host" ;;
        *.container.d/local.conf|infra/config/litellm/models.yaml|infra/config/llama-swap/config.yaml)
            fail "${f}: host-specific settings belong in the gitignored file (commit the .example)" ;;
        *.env|*.env.*)
            fail "${f}: .env files hold secrets" ;;
        *.pem|*.key|*.p12|*.pfx|*.jks|*id_rsa*|*id_ed25519*|*id_ecdsa*|*.kubeconfig|*credentials*.json)
            fail "${f}: key, certificate or credential file" ;;
    esac
done

# --- 2. Images pinned by digest ----------------------------------------------
for f in "${FILES[@]}"; do
    case "${f}" in
        infra/quadlet/*.container)
            while IFS= read -r line; do
                fail "${f}: image not pinned by digest: ${line}"
            done < <(content "${f}" | grep -E '^Image=' | grep -v '@sha256:[0-9a-f]\{64\}' || true) ;;
        infra/scripts/*.sh|infra/config/anubis.conf|.github/workflows/*.yml|.github/workflows/*.yaml)
            # Image references assigned in scripts, config and workflows. An empty
            # value (not built yet) is allowed; a tag without a digest is not.
            while IFS= read -r line; do
                fail "${f}: image not pinned by digest: ${line}"
            done < <(content "${f}" | grep -E '^[[:space:]]*[A-Z_]*IMAGE[A-Z_]*:?=?[[:space:]]*"?[a-z0-9.-]+\.[a-z]{2,}/[^"[:space:]]+' \
                | grep -v '@sha256:[0-9a-f]\{64\}' || true) ;;
    esac
    while IFS= read -r hit; do
        fail "${f}:${hit%%:*}: floating :latest tag"
    done < <(content "${f}" | grep -nE '(docker\.io|ghcr\.io|quay\.io|registry\.[a-z.]+)/[^[:space:]"]+:latest\b' || true)
done

# --- 3. Actions pinned to commit SHAs ----------------------------------------
for f in "${FILES[@]}"; do
    case "${f}" in
        .github/workflows/*.yml|.github/workflows/*.yaml)
            while IFS= read -r line; do
                fail "${f}: action not pinned to a commit SHA: ${line}"
            done < <(content "${f}" | grep -E '^[[:space:]-]*uses:[[:space:]]' \
                | grep -vE 'uses:[[:space:]]+(\./|docker://[^[:space:]]+@sha256:[0-9a-f]{64})' \
                | grep -vE '@[0-9a-f]{40}([[:space:]]|$)' || true) ;;
    esac
done

# --- 4. Official model sources, pinned ---------------------------------------
if printf '%s\n' "${FILES[@]}" | grep -qx 'infra/config/models.catalog'; then
    while read -r name repo commit _; do
        case "${name}" in ""|\#*) continue ;; esac
        case "${repo%%/*}" in
            Qwen|ggml-org|openai) ;;
            *) fail "infra/config/models.catalog: ${name}: ${repo} is not an official source (Qwen, ggml-org, openai)" ;;
        esac
        [[ "${commit}" =~ ^[0-9a-f]{40}$ ]] || fail "infra/config/models.catalog: ${name}: revision must be a full commit SHA"
    done < <(content infra/config/models.catalog)
fi

# --- 5. Scripts executable ---------------------------------------------------
for f in "${FILES[@]}"; do
    case "${f}" in
        infra/scripts/*.sh|.githooks/*)
            mode="$(git ls-files -s -- "${f}" | awk '{print $1}')"
            [ -z "${mode}" ] || [ "${mode}" = "100755" ] || fail "${f}: not executable in git (mode ${mode}; git update-index --chmod=+x)" ;;
    esac
done

if [ "${FAIL}" -gt 0 ]; then
    echo "policy: ${FAIL} problem(s)"
    exit 1
fi
echo "policy: ${#FILES[@]} file(s) checked, no problems"
