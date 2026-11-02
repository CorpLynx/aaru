# Patched and mirrored images

When a pinned upstream image has a fixable CRITICAL or HIGH vulnerability
(`image-scan.yml`) and no upstream release fixes it yet, the fix goes here as a
thin layer on the upstream image instead of an exception. An upstream whose
digests do not stay pullable is mirrored here unchanged, so the pin points at
a copy we keep.

| Image | Base | What the layer fixes |
| --- | --- | --- |
| `postgres` | postgres 16.15-alpine | Rebuilds gosu 1.20 from source with the current Go; the shipped binary was built with Go 1.24.6 |
| `litellm` | LiteLLM v1.106.6 (base signature verified against `cosign.pub`) | ddtrace, dnspython, pyasn1 and pypdf in `/app/.venv`; the OS pip wheel |
| `llamacpp` | llama-swap v269 with llama.cpp b12033 | Nothing: an unchanged mirror. Upstream deletes old digests every six hours, so pins must point at a copy we keep |
| `vllm` | vLLM v0.33.0 (interim NVIDIA test host only) | Ubuntu OpenSSL and dirmngr updates; msgpack, urllib3 and setuptools; removes pip, whose bundled copies are outdated even in its latest release |

Each directory has a `Containerfile`, whose `ARG BASE_IMAGE` pins the upstream
digest, and a `smoke.sh` that the build runs against the result.

## Building

Builds run on GitHub Actions, never locally:

```sh
infra/scripts/build-patched-image.sh postgres   # or litellm, vllm
```

The script tags the current commit `image-<name>-<sha>` (it must be clean and
pushed). `patched-image.yml` then:
- checks the base signature where there is a `cosign.pub`
- builds the image
- scans it with Trivy, failing on fixable CRITICAL or HIGH findings outside
  `.trivyignore.yaml`
- runs `smoke.sh`
- pushes the image as `ghcr.io/corplynx/aaru-<name>`

The script then pins the digest in `infra/quadlet/<name>.container`.

## Bumping or retiring

- **New upstream release:** update `BASE_IMAGE`, re-check that each pinned
  package version is still needed and still inside the upstream's own
  version ranges, and rebuild. For LiteLLM, verify the new base with cosign
  first (see `litellm.container`).
- **Upstream ships the fixes:** pin the upstream image directly in the
  Quadlet unit and delete the directory here.
