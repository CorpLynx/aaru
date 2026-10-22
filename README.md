# Aaru — Framework AI Inference Platform

Invite-only, single-host AI inference platform serving locally hosted language models
through an OpenAI-compatible API, with a web chat/RAG interface.

## Hardware

- **Framework Desktop** — AMD Ryzen AI Max+ 395 (Strix Halo, gfx1151)
- 128GB LPDDR5X-8000 unified memory, Radeon 8060S iGPU (40 CUs)
- Fedora Server (pre-built or DIY with Fedora)
- 2× M.2 2280 NVMe slots for storage

## Documentation

- [Build Specification](framework_ai_server_architecture-2.md) — full architecture, security model, phases, and open decisions
- [Design handoff](design/README.md) — design system, surface specs, and HTML design references (see spec §7a for where it differs from the build spec)

## Project Structure

```
aaru/
├── framework_ai_server_architecture-2.md   # Build spec
├── README.md                               # This file
├── infra/                                  # Deployment configs (Quadlet, compose, scripts)
│   ├── quadlet/                            # Podman Quadlet systemd units
│   ├── config/                             # Service configuration files
│   └── scripts/                            # Setup and maintenance scripts
├── design/                                 # Design handoff: design system, specs, HTML references
├── forks/                                  # Git submodules for UI forks
│   └── open-webui/                         # CorpLynx/open-webui (patches listed in AARU.md)
└── docs/                                   # Product, security, privacy, operator docs
```

## Status

Phase 0 — Hardware and model proof. Interim testing on RTX 4070 Ti Super (16GB VRAM, CUDA) while Framework Desktop is being acquired.

Web UI: Aaru theme layer (tokens, fonts, branding) in progress on `forks/open-webui` branch `aaru/theme-tokens`. Encryption, billing and tier work from the design handoff wait on open decisions 10–14 in the spec.