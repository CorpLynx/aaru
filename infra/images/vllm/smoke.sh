#!/usr/bin/env bash
# Imports vLLM (no GPU needed) and the upgraded packages.
set -euo pipefail
docker run --rm --network none --entrypoint python3 "$1" -c '
import importlib.metadata as m
import msgpack, urllib3, setuptools
import vllm
for p in ("vllm", "msgpack", "urllib3", "setuptools"):
    print(p, m.version(p))
'
