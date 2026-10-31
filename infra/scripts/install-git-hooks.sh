#!/usr/bin/env bash
# Aaru Git Hooks
# Points this clone at .githooks/: pre-commit scans staged changes for secrets
# and checks repository policy; pre-push scans outgoing commits. Run once per
# clone. Requires gitleaks (brew install gitleaks, or dnf install gitleaks).

set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

command -v gitleaks >/dev/null 2>&1 || { echo "ERROR: install gitleaks first (brew install gitleaks)"; exit 1; }
git config core.hooksPath .githooks
chmod +x .githooks/*
echo "Hooks installed (core.hooksPath=.githooks): pre-commit, pre-push"
echo "gitleaks $(gitleaks version)"
