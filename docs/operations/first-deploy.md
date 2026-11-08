# First deployment (Tailscale pilot)

How to take a fresh Fedora host to a running Aaru that invited members reach
over Tailscale. Cloudflare is not part of this path; when it goes live, see
`infra/terraform/README.md` and the last section of
`infra/terraform/tailscale/README.md`.

Work through the steps in order. Each one ends with a check; do not move on
until it passes.

Placeholders used throughout:

| Placeholder | Meaning |
| --- | --- |
| `<admin>` | your sudo-capable admin account on the host |
| `<host>` | the host's address (LAN IP at first, `aaru-host` once on the tailnet) |
| `<tailnet>` | your tailnet's DNS name, e.g. `tail1234` in `tail1234.ts.net` (admin console → DNS) |

## Who runs what

- **Workstation:** your own machine, with Terraform 1.10 or later, the AWS CLI
  with admin credentials, and the repository cloned. Terraform state and the
  Tailscale and AWS credentials stay here.
- **`<admin>` on the host:** hardening and anything that needs root. This is
  the only account SSH admits once the host is hardened.
- **`aaru` on the host:** the service user that owns every container. You
  reach it from `<admin>` with `sudo as-aaru` (a shell) or
  `sudo as-aaru <command>`. `harden-host.sh` installs `as-aaru`. A piped
  command such as `… | ssh <admin>@<host> sudo as-aaru <script>` runs that
  script as `aaru` with your input passed to it.

## Before you start

- [ ] Fedora Server installed, SELinux enforcing (`getenforce`), GPU drivers working.
- [ ] `<admin>` exists, is in `wheel`, and has your SSH key in `~/.ssh/authorized_keys`.
      Hardening turns password logins off and stops if the key is missing.
- [ ] Enough disk for the models. The full catalog is roughly 140 GB; check
      `df -h /home` before step 7.
- [ ] A Tailscale account for Aaru. The Terraform policy replaces the whole
      tailnet policy, so a tailnet used only for Aaru is simplest.
- [ ] A Tailscale API access token, or an OAuth client with the policy file
      and auth keys scopes.
- [ ] An AWS account for Terraform state and backups.
- [ ] A long random [ntfy](https://ntfy.sh) topic for alerts, and the ntfy app
      subscribed to it.
- [ ] The operator details for the legal pages: legal name, contact and
      security emails, jurisdiction.

## 1. Terraform state bucket (workstation)

Follow section 1 of `infra/terraform/README.md` ("Bootstrap the state
bucket"). It is a two-phase apply. Note the `backend_config` output; every
other stack's `backend.hcl` uses it.

**Check:** `terraform -chdir=infra/terraform/bootstrap output backend_config` prints the bucket and region.

## 2. Tailscale policy and auth keys (workstation)

In the Tailscale admin console, under **DNS**, turn on **MagicDNS** and
**HTTPS Certificates**. The app node's HTTPS needs both.

```sh
cd infra/terraform/tailscale
cp backend.hcl.example backend.hcl            # bucket and region from step 1
cp terraform.tfvars.example terraform.tfvars  # admin_logins = your Tailscale login
export TAILSCALE_API_KEY='tskey-api-...'      # or the OAuth client variables
terraform init -backend-config=backend.hcl
terraform apply
```

If the tailnet already has a policy, the first apply stops rather than
overwrite it. Copy its rules into the `extra_*` variables, then set
`overwrite_policy = true`. The auth keys expire after 7 days
(`auth_key_expiry_days`), so finish steps 5 and 13 within a week or re-apply.

**Check:** the admin console's Access Controls page shows `tag:aaru-app` and
`tag:aaru-host`, and the DNS page shows your `<tailnet>.ts.net` name.

## 3. Backup bucket and key (workstation)

```sh
cd infra/terraform/backup
cp backend.hcl.example backend.hcl
cp terraform.tfvars.example terraform.tfvars  # region and bucket prefix
terraform init -backend-config=backend.hcl
terraform apply
```

The host gets its credentials in step 10. See `infra/terraform/backup/README.md`
for retention and Object Lock.

**Check:** `terraform output` shows `bucket_name` and `kms_key_arn`.

## 4. Harden the host (`<admin>`)

SSH in as `<admin>` over the LAN and clone the repository into your own home.
This copy is only for running root scripts; the service user gets its own in step 6.

```sh
git clone https://github.com/CorpLynx/aaru.git ~/aaru
cd ~/aaru
# Dry run: prints every change and changes nothing.
sudo infra/scripts/harden-host.sh --admin-user <admin> --ssh-from <your LAN CIDR, e.g. 192.168.1.0/24>
sudo infra/scripts/harden-host.sh --admin-user <admin> --ssh-from <your LAN CIDR> --apply
```

This creates the `aaru` user (no sudo, lingering on, in the GPU groups),
installs `as-aaru`, locks SSH to `<admin>` and keys only, moves every
interface into the `drop` zone with SSH open only from `--ssh-from`, disables
Cockpit, and turns on fail2ban, auditd, a 30-day journal, security-update
downloads and a weekly Lynis audit. It refuses to run if it would cut off your
current SSH session.

**Check:** keep this session open and, from a second terminal,
`ssh <admin>@<host>` still works. `sudo as-aaru whoami` prints `aaru`.

## 5. Admin SSH over the tailnet (`<admin>`)

From the workstation:

```sh
terraform -chdir=infra/terraform/tailscale output -raw host_auth_key \
  | ssh <admin>@<host> sudo aaru/infra/scripts/tailscale-host.sh
```

Then **reconnect over the tailnet** (`ssh <admin>@aaru-host`) and limit SSH to it:

```sh
cd ~/aaru
sudo infra/scripts/harden-host.sh --admin-user <admin> --ssh-from tailscale0 --apply
```

This removes the LAN CIDR from the admin zone. Run it from the tailnet
session, or the lockout check stops it. Optionally turn on
[tailnet lock](https://tailscale.com/kb/1226/tailnet-lock) now.

**Check:** `ssh <admin>@aaru-host` works and `ssh <admin>@<LAN IP>` times out.
From here on, `<host>` means `aaru-host`.

## 6. Service user checkout (`aaru`)

```sh
sudo as-aaru git clone https://github.com/CorpLynx/aaru.git aaru
sudo as-aaru     # a shell as aaru, in /home/aaru; steps 7–9 and 11–15 run here
```

**Check:** `systemctl --user status` works in that shell (no "Failed to connect to bus").

## 7. Models (`aaru`)

Production host (AMD, llama.cpp on Vulkan):

```sh
cd ~/aaru
infra/scripts/fetch-models.sh
```

Each model is pinned to a commit, checked against the hub's SHA-256 and
scanned by Anubis. A model that fails the scan lands in
`models/.quarantine/`, not `models/`, and the run stops. Read its
`.anubis-report.json` before doing anything else with it.

NVIDIA test host (vLLM): fetch one small model that fits the card instead,
with `infra/scripts/fetch-model.sh <hf-repo> <commit> <model-dir> --include '<glob>'`.

**Check:** `ls ~/aaru/models` lists the five catalog directories (or your one
test model), each with a `.aaru-model.json`.

## 8. Host settings and legal pages (`aaru`)

These files are gitignored; each host keeps its own.

```sh
cd ~/aaru
# Production host
cp infra/config/llama-swap/config.yaml.example infra/config/llama-swap/config.yaml
cp infra/quadlet/llamacpp.container.d/local.conf.example infra/quadlet/llamacpp.container.d/local.conf
# Test host instead: infra/quadlet/vllm.container.d/local.conf.example → local.conf
cp infra/config/litellm/models.yaml.example infra/config/litellm/models.yaml
cp infra/quadlet/openwebui.container.d/local.conf.example infra/quadlet/openwebui.container.d/local.conf
cp legal/legal.conf.example legal/legal.conf
```

Then edit each one:

| File | Set |
| --- | --- |
| `llama-swap/config.yaml` | one entry per model you fetched; the example matches the full catalog |
| `llamacpp.container.d/local.conf` | `Memory=`: both embedding models plus the largest chat model and its KV cache, with headroom for the host and the other containers |
| `vllm.container.d/local.conf` (test host) | `Memory=` and the `Exec=` line for your model |
| `litellm/models.yaml` | the production block as is, or on the test host only the commented vLLM block. Without an `embed` alias, document uploads in the web app fail. |
| `openwebui.container.d/local.conf` | `WEBUI_URL` and `CORS_ALLOW_ORIGIN` = `https://aaru.<tailnet>.ts.net` |
| `legal/legal.conf` | operator name, contacts, jurisdiction; `SERVICE_URL=https://aaru.<tailnet>.ts.net` |

The examples use invalid placeholders on purpose: an unedited copy fails when
the unit is generated instead of starting with a wrong size.

```sh
infra/scripts/render-legal.sh
```

**Check:** `legal/site/terms.html` exists, and
`grep -n '^[^#].*<' infra/quadlet/*.container.d/local.conf legal/legal.conf` finds no leftover
`<placeholder>`.

## 9. Install the units and create secrets (`aaru`)

```sh
cd ~/aaru
infra/scripts/setup.sh                       # production: Tailscale ingress, llama.cpp
# infra/scripts/setup.sh --inference vllm    # NVIDIA test host
```

It installs only the chosen ingress and inference units (here `tailscale` and
`llamacpp`, never `cloudflared`), the host settings from step 8, the backup
and health units, and enables the Podman socket for Dozzle. It then prints
the commands for the secrets. Run the ones under **Create secrets**, except
`set-backup-credentials.sh` (step 10) and the web app key (step 11).

**Check:** `podman secret ls` shows `postgres-password`,
`litellm-db-password`, `litellm-database-url`, `openwebui-db-password`,
`openwebui-database-url`, `litellm-master-key`, `llama-swap-api-key` and
`openwebui-secret-key`.

## 10. Backup credentials (workstation)

```sh
terraform -chdir=infra/terraform/backup output -raw install_command
```

Replace `<admin>` and `<host>` in the printed command and run it. It creates
the backup user's access key and installs it straight into the `aaru-backup-aws`
Podman secret, so it never lands in Terraform state or a file.

**Check:** on the host, `sudo as-aaru podman secret exists aaru-backup-aws && echo ok`
prints `ok`, and `sudo as-aaru ls .config/aaru/backup.env` finds the file.

## 11. Start the stack (`aaru`)

```sh
systemctl --user start aaru-ingress-network.service aaru-internal-network.service aaru-admin-network.service
systemctl --user start postgres.service
systemctl --user start llamacpp.service      # or vllm.service on the test host
systemctl --user start litellm.service
curl -s http://127.0.0.1:4000/health/liveliness   # repeat until it answers
infra/scripts/member.sh webapp-key           # the web app's own LiteLLM key
systemctl --user start openwebui.service
```

The web app will not start without the key from `member.sh webapp-key`. Its
first start takes a minute or two; `podman logs -f openwebui` shows progress.

**Check:** `systemctl --user is-active postgres llamacpp litellm openwebui`
prints `active` four times, and
`curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:3000/health` prints `200`.

## 12. Create the web app admin (workstation)

**Do this before step 13.** The first account created becomes admin, even with
sign-up off, so nobody else may reach the app before you have signed up.

```sh
ssh -L 3000:127.0.0.1:3000 <admin>@<host>
```

Open `http://localhost:3000` in Chrome or Firefox (Safari drops the app's
secure cookies on localhost) and sign up.

**Check:** you are signed in and the admin panel is available.

## 13. Member ingress over Tailscale

From the workstation:

```sh
terraform -chdir=infra/terraform/tailscale output -raw app_auth_key \
  | ssh <admin>@<host> sudo as-aaru aaru/infra/scripts/set-tailscale-authkey.sh
```

On the host, as `aaru`:

```sh
systemctl --user start tailscale.service
podman logs -f tailscale      # wait for it to log in and serve
```

**Check:** from a device signed in to your tailnet, `https://aaru.<tailnet>.ts.net`
shows the sign-in page with a valid certificate, and
`curl -s -o /dev/null -w '%{http_code}\n' https://aaru.<tailnet>.ts.net:8443/v1/models` prints `401`.
The first HTTPS request can take a few seconds while the certificate is issued.

## 14. Logs, alerts and backups (`aaru`)

```sh
systemctl --user start dozzle.service        # http://127.0.0.1:8088 over an SSH tunnel
install -m 600 /dev/null ~/.config/aaru/alerts.env
echo 'AARU_NTFY_URL=https://ntfy.sh/<your-topic>' > ~/.config/aaru/alerts.env
infra/scripts/notify.sh default 'Aaru test alert'
systemctl --user enable --now aaru-healthcheck.timer
systemctl --user start aaru-backup.service   # the first backup, now
journalctl --user -u aaru-backup.service -n 30
systemctl --user enable --now aaru-backup.timer
infra/scripts/restore-drill.sh               # required before any member joins
```

**Check:** the test alert reaches your phone, the backup log ends with
`Backup complete`, the drill ends with `Restore drill PASSED`, and
`infra/scripts/healthcheck.sh --print` shows no `FAIL`.

## 15. Verify (`aaru`, then workstation)

On the host:

```sh
infra/scripts/verify.sh
```

It must run as `aaru`, not root, so it cannot read the firewall zones and
skips that check. As `<admin>`, confirm them by hand:
`sudo firewall-cmd --get-active-zones` should list only `drop` and `aaru-admin`
(holding `tailscale0`), and `sudo firewall-cmd --zone=aaru-admin --list-services`
should print only `ssh`.

Fix every `FAIL`. `WARN`s you can expect for the pilot include the draft legal
pages (until counsel review) and the writable root filesystem and kept
capabilities of PostgreSQL, which needs both.

From the workstation, on a network other than the host's:

```sh
infra/scripts/verify.sh --outside <host public IP> --api-url https://aaru.<tailnet>.ts.net:8443
```

**Check:** both runs end with `0 failed`.

## 16. Invite the first member

Follow "Adding a member" in `infra/terraform/tailscale/README.md`: share the
`aaru` node, get the member's written agreement to the Terms, create their web
app account, then `infra/scripts/member.sh add <email> --terms-accepted <YYYY-MM-DD>`.
Send them the member guide at `https://aaru.<tailnet>.ts.net/legal/guide.html`.

Before the first invite, go through "Before launch" in `docs/compliance.md`.

## If something fails

| Symptom | Likely cause |
| --- | --- |
| `as-aaru: no systemd user session` | lingering is off: `sudo loginctl enable-linger aaru` |
| A unit fails at generation (`systemctl --user status <unit>` shows no unit) | a `local.conf` still has a `<placeholder>`; `/usr/libexec/podman/quadlet -dryrun -user` shows which |
| `openwebui` fails to start | `openai-api-key` missing (step 11), or `legal/site` not rendered (step 8) |
| `llamacpp` restarts | `Memory=` too small for the preloaded embedding model, or a `config.yaml` path that is not under `/models` |
| `tailscale` logs `invalid key` | the auth key expired or was spent; `terraform apply -replace=tailscale_tailnet_key.app`, then step 13 again |
| HTTPS on the `ts.net` name fails | MagicDNS or HTTPS Certificates is off (step 2) |
| `healthcheck.sh` reports `cloudflared` | an earlier install copied it; re-run `infra/scripts/setup.sh` to remove it |
