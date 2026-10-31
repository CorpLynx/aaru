#!/usr/bin/env bash
# Aaru Pinned Images
# Prints every container image the deployment runs, one "<name> <ref>" per
# line: the Quadlet units, the aws-cli image backup.sh uses, and the Anubis
# scanner. Used by .github/workflows/image-scan.yml.
#
# Usage: infra/scripts/list-images.sh [--json]   (--json: a GitHub Actions matrix)

set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."

{
    for unit in infra/quadlet/*.container; do
        ref="$(sed -n 's/^Image=//p' "${unit}")"
        [ -n "${ref}" ] && echo "$(basename "${unit}" .container) ${ref}"
    done
    echo "aws-cli $(sed -n 's/^AWS_CLI_IMAGE="\(.*\)"$/\1/p' infra/scripts/backup.sh)"
    anubis="$(sed -n 's/^ANUBIS_IMAGE=//p' infra/config/anubis.conf)"
    [ -n "${anubis}" ] && echo "anubis ${anubis}"
} | if [ "${1:-}" = "--json" ]; then
    python3 -c 'import json, sys; print(json.dumps({"include": [dict(zip(("name", "ref"), l.split())) for l in sys.stdin if l.strip()]}))'
else
    cat
fi
