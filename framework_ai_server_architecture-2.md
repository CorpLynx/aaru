# Framework AI Inference Platform — Build Specification

**Status:** Draft for iteration (v0.7) — server scaffold started 
**Last reviewed:** 2026-10-22  
**Target:** Single-host Fedora deployment serving local models through an OpenAI-compatible API, with a web chat/RAG front end.

## 1. Goals, scope, and assumptions

### Goals

- Provide authenticated API access to locally hosted language models.
- Offer a browser-based chat client and, later, user document retrieval (RAG).
- Separate public ingress, applications, databases, and inference services.
- Keep persistent user data encrypted at rest and minimize sensitive logging.
- Reuse maintained projects rather than implementing a model server, gateway, UI, or vector database from scratch.

### Initial scope

- **Target hardware not yet acquired:** Framework Desktop with AMD Ryzen AI Max+ 395 (Strix Halo, gfx1151), 128GB LPDDR5X-8000, Radeon 8060S iGPU (40 CUs), 2× M.2 2280 NVMe slots. Available pre-built with Fedora or as DIY. Framework confirms 128GB runs DeepSeek V4 Flash 0731 (UD-IQ2_XXS, ~90.9GB) with headroom for context.
- **Interim test hardware available:** NVIDIA RTX 4070 Ti Super (16GB VRAM), Ryzen 7/9, 64GB RAM. Useful for validating container infrastructure, Quadlet deployment, LiteLLM gateway, Open WebUI integration, and security hardening. Inference will use CUDA/vLLM instead of Vulkan/llama.cpp on the iGPU. AMD-specific validation (TTM tuning, Vulkan backend, unified memory) remains blocked until the Framework Desktop arrives.
- One inference backend and one or more pinned model artifacts for the first release.
- OpenAI-compatible chat/completions API; streaming support must be verified end to end.
- Open WebUI is the primary chat UI and its installable PWA is the default mobile experience. A separate native mobile app is optional; RAG is not required for the first API proof of concept.
- The service is invite-only in v1. The proposed $25/$70/$150 subscription tiers are future commercial requirements to validate, not current v1 scope; key provisioning is operator-controlled.
- Initial Open WebUI deployment is capped at 50 users in any rolling 30-day period to match the selected current-license rebranding path; revisit licensing before raising the cap.

### Explicit non-goals for v1

- Zero-knowledge storage, protection from a live host root administrator, high availability, or certified security compliance.
- Running a coding-agent runtime, shell/PTY tools, or per-user code workspaces. Aaru serves model inference; it does not run OpenCode servers.
- Arbitrary model tool execution, web browsing, or user-provided plugins in the first release.
- Guaranteed throughput or unlimited use until a capacity test and fair-use policy exist.

## 2. Proposed architecture

```text
API clients ─> Cloudflare edge ─> cloudflared ─> LiteLLM ─> optional checks ─> llama.cpp
Browsers ────> Cloudflare edge ─> cloudflared ─> Web UI ───────> LiteLLM
                                                         ├─────> PostgreSQL (UI data)
                                                         └─────> encrypted upload storage
LiteLLM ────────────────────────────────────────────────────────> PostgreSQL (keys/metadata)

Mobile browser/PWA ─> chat.<domain> ─> Web UI ─> LiteLLM
Optional native chat app ─> Web UI (user login) or LiteLLM (individual virtual key)
```

- `api.<domain>` routes through the Cloudflare Tunnel to LiteLLM; `chat.<domain>` routes to the selected web UI. Keep inference and database ports unpublished on the host.
- `cloudflared` is an outbound tunnel connector, not an application firewall. It should reach only the ingress-facing services on a dedicated Podman network.
- LiteLLM authenticates API keys, applies model access and quotas, and forwards requests to the inference service over a private container network.
- The web UI calls LiteLLM rather than bypassing it. Do not put the LiteLLM master/admin key in the UI or in client applications.
- Open WebUI's PWA is the default mobile client. If a native client is added, it must use Open WebUI's user-authenticated API or an individual LiteLLM virtual key; it must never receive the LiteLLM master key.
- PostgreSQL is private. Use separate databases and least-privilege roles for LiteLLM and the UI, even if they share one PostgreSQL instance.
- If RAG is enabled, user uploads, extracted text, embeddings, and vector records are all sensitive user data and need matching access controls, retention, and deletion behavior.

## 3. Reuse existing projects

| Capability | Proposed project | Notes / decision |
| --- | --- | --- |
| Containers and lifecycle | [Podman](https://github.com/containers/podman) + systemd [Quadlet](https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html) | Use rootless containers where practical. Prefer Quadlet-managed systemd units over introducing `podman-compose` for a single-host service. |
| Primary inference | [llama.cpp](https://github.com/ggml-org/llama.cpp) | Start with Vulkan on the AMD iGPU and its OpenAI-compatible server. Pin image/source revision and model artifact; benchmark on the actual machine before promising model or throughput tiers. |
| Alternative inference | [vLLM](https://github.com/vllm-project/vllm) | Current vLLM docs list AMD Ryzen AI Max/gfx1151 and ROCm support. Treat it as an experiment/alternative: validate the exact Fedora kernel, ROCm stack, container device access, model, and performance before adopting. CUDA/RTX 3090 is not a requirement for vLLM. |
| API gateway and keys | [LiteLLM Proxy](https://github.com/BerriAI/litellm) | Existing virtual keys, model allowlists, rate limits, budgets, and usage tracking avoid a custom gateway. Verify exact OSS feature/license needs and test quota enforcement under concurrent load. |
| Web chat / mobile PWA / RAG | [Open WebUI](https://github.com/open-webui/open-webui) | Primary UI; it includes an installable PWA for iOS/Android browsers, so a second app is not required for v1. Its current license has a branding condition; the selected reskin plan is capped at 50 users per rolling 30 days. If strict OSI-approved licensing is required, evaluate LibreChat (MIT) and account for its different backing services/configuration. |
| Relational DB / vectors | [PostgreSQL](https://www.postgresql.org/) + [pgvector](https://github.com/pgvector/pgvector) | pgvector provides vector and hybrid search inside Postgres. Use only if the selected UI/RAG implementation supports it well; otherwise choose a supported vector store such as [Qdrant](https://github.com/qdrant/qdrant), with tenant isolation designed explicitly. |
| Subscription billing (paid launch) | [Lago](https://github.com/getlago/lago) or an existing payment/billing provider | Lago is a self-hostable billing/metering platform (AGPLv3) with subscription and usage features. Evaluate its license, payment-provider integration, and operational footprint before adopting; it is likely too much for the invite-only pilot. LiteLLM is not a substitute for billing. |
| Optional native mobile chat | [Conduit](https://github.com/cogwheel0/conduit) | Native iOS/Android client for Open WebUI and direct OpenAI-compatible endpoints, including LiteLLM-style APIs. GPL-3.0; evaluate distribution/source obligations before forking. The Open WebUI PWA remains the default and simplest mobile option. |
| Security guidance | [OWASP GenAI Security Project](https://genai.owasp.org/llm-top-10/) | Use its guidance as a review checklist; no classifier or prompt filter makes an LLM secure by itself. |
| Public ingress | [cloudflared](https://github.com/cloudflare/cloudflared) + Cloudflare Tunnel/WAF | The connector is open source; the edge service is a third-party dependency and sees traffic at the Cloudflare edge. Review its data handling and plan limits. |
| Container log viewer | [Dozzle](https://github.com/amir20/dozzle) | MIT-licensed, lightweight real-time log viewer for Podman/Docker. No log storage — purely live viewing. Admin-only access via Tailscale. |

Re-check licenses, release status, hardware compatibility, and security advisories when pinning versions. A project being popular or open source does not make it a security boundary.

### GUI forks and source layout

- Keep the web UI fork independent from infrastructure and operations. The Open WebUI PWA ships with the web fork; add a separate native client only if the PWA is insufficient.
- Proposed paths inside a future source monorepo:
 
  ```text
  forks/
    open-webui/       # our maintained fork of Open WebUI (includes PWA)
    conduit/          # optional native mobile client; only if PWA is insufficient
  infra/              # Podman/Quadlet deployment and shared configuration
  docs/               # product, security, privacy, and operator docs
  ```

- **Selected layout:** Git submodules pointing at **our own fork repositories**, with each fork retaining its own Git history and a documented `upstream` remote. The parent repository pins the exact commit used for each build.
- Keep product-specific changes small and isolated (theme tokens, logos, copy, app identifiers, endpoint defaults) so upstream security and compatibility fixes remain mergeable. Record custom patches and upstream sync dates in each fork's README.
- The current `aaru` workspace is not a Git repository and contains only this spec. The monorepo layout is selected, but the parent repository/submodules are not initialized until the GitHub namespace and fork URLs are known.

#### Open WebUI reskin gate

- Open WebUI's current license page says deployments with **50 or fewer users in any rolling 30-day period** may rebrand; larger deployments must retain the original prominent branding or obtain a license that permits rebranding. The invite-only v1 cap (50 users) matches this exception, but any increase requires a license review. Re-check the full license and obtain legal advice before raising the cap or launching publicly.
- Alternative: start from Open WebUI v0.6.5 or earlier, whose code is BSD-3-Clause, if permissive rebranding is more important than current upstream. This trades away later upstream code/fixes; do not copy post-v0.6.5 code into that branch without checking its license.
- If operating under current terms with branding retained, UI changes must not obscure, recolor, relocate, or co-brand in a way that violates the current branding policy. Make the license path a decision before implementation, not a cleanup task after the reskin.

#### Mobile client decision
 
- **v1: Open WebUI PWA.** Open WebUI officially documents installable iOS/Android PWA support. Admins can set a custom PWA manifest for app name/icon/theme color. This reuses Aaru's existing authenticated chat UI and needs no separate native client or OpenCode server.
- **Future: dedicated Aaru native mobile app.** Planned for a later phase, after the PWA is validated with invited users. Candidate base: [Conduit](https://github.com/cogwheel0/conduit) (Flutter, GPL-3.0) — native iOS/Android, supports Open WebUI accounts and direct OpenAI-compatible endpoints, stores credentials in Keychain/Keystore. A direct LiteLLM connection must use one end-user virtual key with the user's model/quotas—not a shared gateway key.
- Conduit is GPL-3.0. If Aaru distributes a modified client, preserve notices and provide corresponding source under GPL-3.0; confirm app-store/signing and distribution obligations before adopting. Do not assume its license permits a closed-source reskin.
- **OpenCode/OpenChamber are out of scope for Aaru v1.** They provide coding-agent runtimes/workspaces and remote tool execution. Aaru does not run an OpenCode server, and those clients are not substitutes for mobile chat over Aaru's OpenAI-compatible inference API.

### Logging and monitoring

- **Dozzle** ([amir20/dozzle](https://github.com/amir20/dozzle)): MIT-licensed, lightweight real-time container log viewer. Supports Podman/Docker. No log storage — purely live viewing. Useful for operational debugging without setting up a full Loki/Grafana stack.
- Dozzle connects to the Podman socket (read-only) to stream container logs. It must be restricted to admin access via Tailscale or a private network — never exposed publicly.
- For persistent log retention and alerting, evaluate **Loki + Grafana** as a later addition. Dozzle is sufficient for v1 operational debugging.
- Dozzle does not store logs; pair with `podman logs` and systemd journal for persistent audit trails.

## 4. Host and AMD unified-memory configuration

- Use a supported Fedora Server release with current firmware and a kernel containing the AMD Ryzen AI Max/gfx1151 support fixes. Current AMD documentation identifies kernel 6.18.4 or later for generic distributions and lists Fedora 43 as including the required native fixes; verify the actual release/kernel in use.
- Keep SELinux enforcing and firewalld enabled. Do not use privileged containers or disable SELinux as a shortcut for GPU access.
- The Radeon 8060S uses physically shared system memory. A “124 GB VRAM allocation” is not a separate reservation and leaves insufficient headroom for Fedora, containers, PostgreSQL, and request buffers.
- Do **not** use `amdgpu.gttsize=126976` as the allocation recipe: the kernel documents `gttsize` as a deprecated restriction/testing parameter. Start with defaults, benchmark, then tune the TTM `pages_limit` only if needed and retain explicit host-memory headroom. Follow AMD's current [RDNA 3.5 memory guidance](https://rocm.docs.amd.com/en/latest/reference/system-optimization/rdna3-5.html).
- Run the Podman services under a dedicated unprivileged service account. Pass only the required render/compute device nodes to the inference container and verify that rootless user-namespace and SELinux permissions remain in effect.
- Install only required host packages (for example, Podman, firewalld, and GPU/runtime dependencies). Pin the Fedora release and schedule updates rather than blindly updating the production host on every boot.

## 4a. Security hardening and host lockdown

### User and access model

- Create a dedicated, non-root service account (for example, `aaru`) for running all Podman workloads. This account must not have sudo privileges and must use a strong, unique password or SSH key authentication only.
- Create a separate administrative account (for example, `admin`) with sudo access, used only for host maintenance. This account should be distinct from the primary personal account and protected with MFA.
- Disable root login entirely (`PermitRootLogin no` in `/etc/ssh/sshd_config`). Lock the root account password (`passwd -l root`).
- Enforce SSH key-based authentication only. Disable password authentication (`PasswordAuthentication no`) and keyboard-interactive authentication (`KbdInteractiveAuthentication no`).
- Set `AllowUsers` or `AllowGroups` in sshd_config to restrict SSH access to explicitly named accounts.
- Configure account lockout after failed attempts using `fail2ban` or `pam_faillock`. Set a reasonable lockout threshold (e.g., 5 attempts, 15-minute lockout).
- Enforce password complexity and rotation via PAM (`pam_pwquality`) if passwords are used at all.

### Tailscale (admin remote access)

- Install Tailscale on the host for secure, identity-based admin access. Tailscale provides encrypted WireGuard tunnels without exposing ports to the public internet.
- Enable Tailscale SSH (`tailscale up --ssh`) to provide authenticated, MFA-gated SSH access over the tailnet. This eliminates the need to expose port 22 to the internet or configure SSH key distribution manually.
- Restrict Tailscale ACLs to allow only the admin account's devices to reach the host on port 22. Deny all other tailnet devices.
- Tailscale should be used for all administrative access. The public SSH port (22) should be firewalled off entirely or bound to localhost only.
- Do not use Tailscale for application traffic (API/UI access) — that goes through Cloudflare Tunnel. Tailscale is for admin/operational access only.

### Firewall (firewalld)

- Default zone: `drop` or `block` — deny all inbound traffic by default.
- Allow only:
  - SSH (port 22) from the admin's management IP or Tailscale interface only.
  - HTTPS (port 443) if needed for local testing; production traffic goes through Cloudflare Tunnel (outbound).
- Explicitly deny all other inbound ports, including 4000, 8080, 3000, 5432, and any container-internal ports.
- Enable firewalld logging for denied packets to detect scanning or brute-force attempts.
- Verify rules with `firewall-cmd --list-all` and test from an external host.

### SELinux

- Keep SELinux in `enforcing` mode at all times. Never set it to `permissive` or `disabled`, even temporarily for debugging.
- Use `container_t` context for all Podman containers. Verify with `ps -eZ | grep container_t`.
- If a container fails due to SELinux, diagnose with `ausearch -m avc -ts recent` and use `audit2allow` to generate a minimal policy module rather than disabling SELinux.
- Set SELinux booleans only as needed (e.g., `container_use_devices` for GPU access) and document each exception.

### Security scanning and hardening tools

- **Lynis** (`sudo dnf install lynis`): Run `sudo lynis audit system` as part of initial hardening and periodically thereafter. Address all warnings and suggestions. Lynis covers kernel hardening, SSH configuration, file permissions, and service auditing.
- **OpenSCAP** (`sudo dnf install openscap-scanner scap-security-guide`): Run the Fedora security baseline profile: `oscap xccdf eval --profile xccdf_org.ssgproject.content_profile_standard --results results.xml /usr/share/xml/scap/ssg/content/ssg-fedora-ds.xml`. Remediate findings before production.
- **Trivy** (container image scanning): Scan all container images before deployment: `trivy image <image>`. Block deployment of images with critical or high vulnerabilities unless explicitly accepted with a documented exception.
- **ClamAV** (optional, for uploaded documents): If RAG is enabled, scan uploaded files for malware before processing. Not required for v1 without RAG.
- **AIDE** (`sudo dnf install aide`): Initialize a file integrity database after hardening: `aide --init`. Schedule periodic checks via cron to detect unauthorized file changes.
- **fail2ban**: Configure for SSH and any exposed service. Ban IPs after repeated failed authentication attempts.

### System hardening

- Disable unnecessary services and daemons (`systemctl disable --now <service>`). Audit with `systemctl list-unit-files --state=enabled`.
- Set kernel parameters for security:
  - `kernel.randomize_va_space=2` (ASLR)
  - `net.ipv4.conf.all.rp_filter=1` (reverse path filtering)
  - `net.ipv4.conf.all.accept_redirects=0` (disable ICMP redirects)
  - `net.ipv4.conf.all.send_redirects=0`
  - `net.ipv4.tcp_syncookies=1` (SYN flood protection)
  - `fs.suid_dumpable=0` (disable core dumps for setuid)
- Disable USB auto-mount and restrict USB access if not needed for operations.
- Set `umask 027` for the service account to ensure new files are not world-readable.
- Configure `auditd` to log security-relevant events: authentication, sudo usage, file changes in `/etc`, and container starts/stops.
- Enable automatic security updates for critical packages only (via `dnf-automatic` with `apply_updates = no` and manual review), or use a scheduled maintenance window.

### Container security

- Run all containers rootless under the dedicated service account. Verify with `podman info | grep rootless`.
- Use read-only root filesystems (`ReadOnly=true` in Quadlet) where the application supports it.
- Drop all unnecessary capabilities (`DropCapability=ALL` then add only required ones).
- Use `NoNewPrivileges=true` on all containers.
- Set memory and CPU limits on every container to prevent resource exhaustion.
- Use `SeccompProfile` to restrict syscalls (default Podman profile is a good baseline).
- Never mount the Podman socket, host root, or `/proc` into application containers.
- Pin container images by digest, not tag, for reproducible and auditable deployments.
- Scan images with Trivy before deployment and on every update.

### Hardening verification checklist

- [ ] Lynis audit score above 80; all critical findings remediated.
- [ ] OpenSCAP standard profile passes with no high/critical findings.
- [ ] All container images scanned with Trivy; no critical vulnerabilities.
- [ ] SSH accessible only via Tailscale or admin management IP; password auth disabled.
- [ ] firewalld default-deny confirmed; only required ports open.
- [ ] SELinux enforcing; no AVC denials in recent audit log.
- [ ] AIDE database initialized; periodic checks scheduled.
- [ ] fail2ban active for SSH.
- [ ] Root login disabled; root password locked.
- [ ] Service account has no sudo; admin account has MFA.
- [ ] All Quadlet units use `NoNewPrivileges`, `ReadOnly`, capability drops, and memory limits.
- [ ] No container has host network, privileged mode, or socket mounts.

## 5. Inference service

- **Initial backend:** `llama.cpp` server using Vulkan, listening on its container network only (for example, port `8080`). Do not publish this port on the host or route a public hostname to it.
- Download model files through a controlled operator workflow. Record model name, exact revision/hash, source, license, quantization, context length, and benchmark results. Mount model artifacts read-only at runtime.
- Select the model after measuring prompt processing, generation speed, context memory, warm-up time, and concurrent sessions. Candidate model names in the previous draft are examples only; no model is selected until its artifact, license, and hardware compatibility are confirmed.
- Disable inference-container egress after model setup where feasible. Do not mount the host filesystem, Podman socket, user home, or secrets into the model container.
- A second backend is a later capacity decision. vLLM can target AMD ROCm as well as NVIDIA CUDA; adding a second model process on a 128 GB shared-memory APU may reduce total capacity rather than increase it. Benchmark before deploying both.

## 6. Gateway, identities, tiers, and billing

- LiteLLM is the sole public OpenAI-compatible API. Expose only required inference routes; keep admin, key-management, health/debug, and configuration endpoints private or operator-authenticated.
- Use LiteLLM virtual keys with explicit model allowlists, RPM/TPM limits, concurrency limits, expiration, and (where suitable) budgets. Create keys through an authenticated operator or provisioning workflow. Store the master key as a secret and rotate it.
- Use stable internal model aliases (for example, `fast` and `reasoning`) rather than hard-coding marketing names in clients. Map subscription entitlements to allowed aliases and quotas in one provisioning source of truth.
- LiteLLM quotas and usage tracking are not a complete recurring subscription/payment system. A billing integration must provision, downgrade, suspend, and revoke keys when a subscription changes. It must also define refunds, cancellation timing, fair use, and usage disputes. A manual invite/key flow is acceptable for a private pilot; automate billing before general sale.
- Flat monthly tiers need tested fair-use limits: one GPU is a shared queue, and API token quotas alone do not guarantee latency. Define maximum parallel requests, queue behavior, token/context caps, and overload responses.
- **Web UI identity is a separate integration risk:** verify how each authenticated UI user maps to an individual LiteLLM key or entitlement. A single shared UI-to-LiteLLM key defeats per-user gateway limits and usage attribution. Do not solve this by exposing an admin/master key. If user-key propagation is unsupported, use an authenticated provisioning/proxy integration or defer per-user UI quotas.
- Do not duplicate prompts, completions, uploaded contents, bearer tokens, or API keys in application/telemetry logs by default. If the UI stores chat history as a product feature, disclose that storage, protect it as user data, and define retention/deletion separately from operational logs. Keep gateway usage metadata to the minimum needed and verify behavior in pinned versions.

## 7. Web UI and RAG

- Host the UI at `chat.<domain>` and require authenticated accounts; disable open registration for the pilot. Add OIDC/MFA or equivalent account lifecycle controls before serving paying users broadly.
- Use the UI's supported PostgreSQL configuration only when verified for the pinned release. Store the UI's full persistent data directory—not only the upload folder—on the protected data volume. Keep LiteLLM and UI database roles separate.
- RAG is a phase-two feature. Enforce per-user or per-tenant authorization on both document metadata and vector retrieval; filtering only in the UI is insufficient. Test that one user's query cannot retrieve another user's chunk.
- Treat uploaded files and retrieved passages as untrusted input. Apply file size/type limits, malware scanning where appropriate, parser isolation, and deletion/retention rules. Do not enable web fetch, arbitrary URL ingestion, tool execution, or community plugins by default.
- If using vector search, prefer pgvector for a small deployment when supported and operationally simpler; evaluate Qdrant when scale or UI support justifies another service. Choose and test the tenant-isolation model before storing customer documents.

## 8. Security and privacy model

### What this design protects

- Rootless containers, SELinux, private networks, least-privilege database roles, and host firewalling reduce exposure from ordinary service compromise and accidental network access.
- LUKS protects data on a powered-off or stolen storage device, assuming the unlock key is not available to the attacker. Encrypt backups separately and test restores.
- Cloudflare Tunnel avoids opening inbound host ports directly to the internet; API authentication and gateway quotas limit unauthorized use.

### What this design does not protect

- **This is not zero-knowledge or end-to-end encrypted chat.** The UI, gateway, inference process, and database application handle plaintext at some point. A host root administrator can read a mounted LUKS filesystem, inspect process memory, or change the running software. A tmpfs-held LUKS key reduces key persistence but does not hide live data from root.
- `pgcrypto` does not automatically encrypt Open WebUI/LiteLLM rows, provide per-user encryption, or make a PostgreSQL administrator unable to read data. PostgreSQL row-level security is authorization defense-in-depth, not encryption, and privileged database roles can bypass it. Do not claim “zero knowledge” unless client-side encryption and key handling are designed end to end; that would constrain server-side search/RAG and normal inference.
- Cloudflare terminates client TLS at its edge and relays traffic through its network. The tunnel protects the origin connection, not confidentiality from Cloudflare. Treat Cloudflare as a data processor and document this to users.

### Required controls

- Prefer full-disk encryption or LUKS for the persistent data volume; do not use EncFS. Protect PostgreSQL, UI state, uploads, vector data, and backups consistently. Define secure key recovery and reboot/unlock procedures.
- Keep API keys and database passwords out of Git, images, command-line arguments, and ordinary environment files. Use Podman secrets or systemd credentials with restrictive file permissions; do not mount the Podman socket into application containers.
- Segment ingress, app, database, and inference traffic. Allow only required paths: tunnel connector to public-facing app ports; UI to LiteLLM and its database; LiteLLM to its database and inference service. No public database/model ports and no model-container egress. Test IPv4 and IPv6 rules, host-gateway paths, and DNS behavior; a Podman bridge alone is not a complete egress policy.
- Use a request-size limit, timeouts, and rate limiting at ingress and gateway. Treat geo-IP filtering as an optional abuse friction—not an authorization or security boundary. Cloudflare WAF/DDoS features and availability vary by plan.
- Keep prompt-injection and content-safety controls separate from infrastructure security. Llama Guard or another moderation/guardrail model may classify inputs/outputs, but cannot guarantee prevention of jailbreaks, SSRF, network scanning, or code execution. For v1, the model has no tools, network access, or execution environment; if tools are added later, isolate and authorize each tool independently and require approval for consequential actions.
- A native mobile client must store user credentials/API keys in iOS Keychain or Android Keystore. Direct LiteLLM clients receive individual virtual keys only; never embed a gateway master key or shared service credential in the app.
- Restrict administrative dashboards and credentials to a private management path; enable MFA for operator accounts. Maintain an incident process for leaked user keys and data deletion requests.

## 9. Network and edge routing

- Use Cloudflare Tunnel for outbound origin connectivity. Configure separate routes for API and UI hostnames; do not expose ports `4000`, `8080`, database ports, or UI admin ports through host firewall/NAT.
- Attach `cloudflared` only to the ingress-facing network it needs. It should not have direct access to PostgreSQL or inference containers.
- Apply WAF/rate/abuse controls at Cloudflare and again at LiteLLM. Add Cloudflare Access only where its identity flow is compatible with the intended clients; API clients still need per-user API-key authentication.
- Route the Open WebUI PWA through `chat.<domain>`. If a native app connects directly to LiteLLM, route it to `api.<domain>` and authenticate with an individual virtual key. Do not create or expose an OpenCode/coding-agent server as part of Aaru v1.
- Verify streaming responses, request-size limits, idle timeouts, and WebSocket/SSE behavior through the actual Cloudflare plan and tunnel configuration.
- The host firewall must default-deny unsolicited inbound traffic except required administration from a restricted management path. Do not rely on rules that only mention `127.0.0.1` or a single RFC1918 subnet; enumerate and test all host and container routes.

## 10. Operations and lifecycle

- Define a deployment repository containing Quadlet units, pinned configuration, schema/setup steps, and non-secret examples. Pin container images by digest (or an equivalent immutable version) and record model hashes.
- Build and test the web UI independently. If a native client is later adopted, maintain its source, license inventory, signing credentials, and upstream security-update cadence separately.
- Scan images/dependencies before production updates, stage updates, and maintain a rollback path. Update Fedora/kernel/firmware deliberately because inference compatibility can change with the GPU stack.
- Monitor host RAM/swap, GPU availability, temperature, disk capacity, request latency, queue depth, errors, and container health. Alert on disk exhaustion, failed backups, unexpected restarts, and sustained overload.
- Back up PostgreSQL and user files on a defined schedule to encrypted off-host storage. Include configuration and key-recovery instructions, but keep secrets protected separately. Perform a restore drill before onboarding paying users.
- Define data retention, account deletion, document deletion across original files and vectors, log retention, and backup expiry. Deletion from the live database does not immediately remove old backup copies.
- Treat the single host, home/office power and internet, and Cloudflare as availability dependencies. Publish maintenance expectations and an outage/support contact before offering a paid service.

## 11. Delivery phases and acceptance criteria

### Phase 0 — Hardware and model proof (interim: NVIDIA test hardware)
 
- **Interim test hardware:** RTX 4070 Ti Super (16GB VRAM), Ryzen 7/9, 64GB RAM. Use this to validate the full stack (containers, gateway, UI, security) before the Framework Desktop arrives.
- On the test machine, use vLLM with CUDA backend instead of llama.cpp/Vulkan. Select a model that fits in 16GB VRAM (e.g., Qwen 2.5 7B or Llama 3.1 8B at Q4).
- Validate: container deployment, Quadlet lifecycle, LiteLLM key enforcement, Open WebUI integration, Cloudflare Tunnel routing, security hardening (Lynis, firewalld, SELinux).
- **Blocked until Framework Desktop arrives:** AMD-specific validation (TTM tuning, Vulkan backend, unified memory behavior, model selection for 128GB). The test machine validates architecture and operations, not final performance.
- Only then select the TTM limit, model artifact, and initial tier limits on the production hardware.

### Phase 1 — Private API pilot

- Deploy Podman/Quadlet, LiteLLM, PostgreSQL, llama.cpp, and cloudflared with no public UI or RAG.
- Confirm no direct host port is reachable for PostgreSQL or inference; API calls without a valid virtual key fail; tier-restricted keys cannot call disallowed aliases; RPM/TPM/concurrency limits reject excess use.
- Confirm model containers have no unexpected outbound network access and logs do not contain prompt text or credentials.

### Phase 2 — Authenticated UI and RAG

- Select UI after license review; add account provisioning, user-to-gateway entitlement mapping, and protected UI storage.
- Verify private conversations and RAG documents cannot be accessed across users. Verify deletion removes document records, source files, and vectors according to the retention policy.
- Test uploads with oversized, malformed, and unsupported files; ensure plugins/tools and arbitrary URL fetching remain disabled unless explicitly reviewed.

### Phase 2b — Mobile web/PWA validation
 
- Test Open WebUI's PWA on iOS Safari and Android Chrome; set the product app name, icon, and theme color through its supported PWA manifest configuration.
- Acceptance: PWA installs on both platforms; unauthenticated users cannot access chats or models; branding and manifest reflect Aaru identity within the 50-user license cap.
 
### Phase 2c — Dedicated mobile app (future, after PWA validation)
 
- Evaluate Conduit (GPL-3.0, Flutter) as the base for a dedicated Aaru native mobile app.
- Decide whether the native app connects through Open WebUI user accounts or directly with an individual LiteLLM virtual key.
- Before distributing a modified Conduit build, review GPL-3.0 source-distribution requirements, app-store/signing implications, and third-party dependencies.
- Keep OpenCode/OpenChamber out of this Aaru deployment.

### Phase 3 — Invite-only launch
 
- Complete operator-controlled key provisioning/revocation, account lifecycle, privacy disclosures, model/license information, and support/outage expectations.
- Test load with expected concurrent invited users, Cloudflare streaming/timeouts, backup restore, key rotation, account removal, and incident response before broader launch.
- Subscription billing integration remains a future phase if public tiers are introduced.

### Release gates

- A clean external scan finds no exposed database or inference port.
- Rootless/SELinux confinement remains enabled for the deployed services.
- Per-plan key tests, UI identity mapping, and tenant-isolation tests pass.
- Backup restore and user-data deletion tests pass.
- Measured capacity supports the published concurrency, context, and usage limits without exhausting host memory.
- Privacy language accurately states that the operator and Cloudflare can process plaintext; no “zero-knowledge” claim is made.

## 12. Open decisions

1. ~~Is the service strictly private/invite-only, or intended for general public sign-up and paid subscriptions?~~ **Decided: invite-only.** The service will not offer public self-service sign-up in v1. Key provisioning is operator-controlled. If public subscription tiers are added later, revisit billing, support, privacy disclosures, and capacity planning.
2. Is protecting data from the host administrator a hard requirement? If yes, the current single-host/server-side design must change substantially.
3. The selected web UI plan is current Open WebUI with full reskin under a hard cap of 50 users per rolling 30 days. What license path should be used if the cap needs to increase?
4. What are target concurrent users, context lengths, expected monthly tokens, uptime, and acceptable response latency for each proposed tier?
5. Is RAG required for v1, and must documents be isolated per person, per team, or both?
6. Should Cloudflare be a trusted data processor, or should public ingress use a different provider/architecture?
7. Which identity and subscription billing systems will be authoritative for account status and entitlements?
8. ~~Is the Open WebUI PWA sufficient for launch, or is a native mobile client required?~~ **Decided: PWA for v1.** A dedicated Aaru native mobile app is planned for a future phase. Conduit (GPL-3.0, Flutter) is the leading candidate for the native app base; evaluate its source-distribution and app-store obligations before forking.
9. What GitHub user/organization namespace should own the Open WebUI fork and (if selected) Conduit fork?

## 13. References

- [AMD RDNA 3.5 system optimization / TTM guidance](https://rocm.docs.amd.com/en/latest/reference/system-optimization/rdna3-5.html)
- [Linux kernel AMDGPU module parameters](https://docs.kernel.org/gpu/amdgpu/module-parameters.html)
- [Podman Quadlet documentation](https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html)
- [llama.cpp](https://github.com/ggml-org/llama.cpp)
- [vLLM AMD ROCm installation](https://github.com/vllm-project/vllm/blob/main/docs/getting_started/installation/gpu.rocm.inc.md)
- [LiteLLM virtual keys](https://docs.litellm.ai/docs/proxy/virtual_keys)
- [Lago](https://github.com/getlago/lago) (subscription/metering candidate; AGPLv3)
- [pgvector](https://github.com/pgvector/pgvector)
- [Open WebUI license](https://docs.openwebui.com/license/), [PWA/mobile install guide](https://docs.openwebui.com/getting-started/open-webui-as-app/), and [LibreChat](https://github.com/LibreChat-AI/LibreChat)
- [Conduit native mobile client](https://github.com/cogwheel0/conduit) (GPL-3.0; Open WebUI and OpenAI-compatible API support)
- [OWASP GenAI Security Project](https://genai.owasp.org/llm-top-10/)
- [Lynis security auditing tool](https://cisofy.com/lynis/)
- [OpenSCAP / SCAP Security Guide](https://www.open-scap.org/)
- [Trivy container image scanner](https://github.com/aquasecurity/trivy)
- [Tailscale SSH](https://tailscale.com/kb/1193/tailscale-ssh)
- [Fedora Server documentation](https://docs.fedoraproject.org/en-US/fedora-server/)
