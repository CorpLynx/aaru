#!/usr/bin/env bash
# Prints llama-swap's version and checks llama-server and curl (the unit's
# health check) are where the deployment expects them, as the unit's user.
set -euo pipefail
docker run --rm --network none --entrypoint /app/llama-swap "$1" -version
docker run --rm --network none --entrypoint sh "$1" -c '
    [ "$(id -u)" = 10001 ] && test -x /app/llama-server && command -v curl >/dev/null'
