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

## Project Structure

```
aaru/
├── framework_ai_server_architecture-2.md   # Build spec
├── README.md                               # This file
├── infra/                                  # Deployment configs (Quadlet, compose, scripts)
│   ├── quadlet/                            # Podman Quadlet systemd units
│   ├── config/                             # Service configuration files
│   └── scripts/                            # Setup and maintenance scripts
├── forks/                                  # (planned) Git submodules for UI forks
│   └── open-webui/                         # Maintained fork of Open WebUI
└── docs/                                   # Product, security, privacy, operator docs
```

## Status

Phase 0 — Hardware and model proof. No services deployed yet.