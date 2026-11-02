#!/usr/bin/env bash
# Starts the image with no network and waits for it to accept connections,
# which exercises the entrypoint's gosu step.
set -euo pipefail
name="smoke-postgres-$$"
trap 'docker rm -f "${name}" >/dev/null 2>&1 || true' EXIT
docker run -d --name "${name}" --network none -e POSTGRES_PASSWORD=smoke "$1" >/dev/null
# On first start the entrypoint runs a temporary server on the Unix socket
# only, so waiting on TCP waits for the real server.
for _ in $(seq 1 90); do
    docker exec "${name}" pg_isready -U postgres -h 127.0.0.1 >/dev/null 2>&1 && break
    sleep 1
done
docker exec "${name}" psql -U postgres -h 127.0.0.1 -tAc 'select version()'
# PID 1 must have dropped to the postgres user.
[ "$(docker exec "${name}" awk '/^Uid:/ {print $2}' /proc/1/status)" = "$(docker exec "${name}" id -u postgres)" ]
