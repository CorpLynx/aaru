#!/usr/bin/env bash
# Imports the proxy and the upgraded packages, and prints LiteLLM's version.
set -euo pipefail
docker run --rm --network none --entrypoint /app/.venv/bin/python "$1" -c '
import importlib.metadata as m
import ddtrace, dns.resolver, pyasn1, pypdf
import litellm.proxy.proxy_server
for p in ("litellm", "ddtrace", "dnspython", "pyasn1", "pypdf"):
    print(p, m.version(p))
'
