# Compliance overview

What Aaru has in place to meet its legal and security obligations, and where
each piece lives. None of this is legal advice; it is the set of controls and
documents a small, private AI service is expected to have, with counsel review
still required before launch.

## Documents members see

| Item | Where |
| --- | --- |
| Terms of Service, with AI-output disclaimer, no-warranty and liability limits | `legal/terms.html` → `/legal/terms.html` |
| Acceptable Use Policy | `legal/acceptable-use.html` |
| Privacy Notice: data inventory, purposes, retention, processors, rights | `legal/privacy.html` |
| Third-party notices: Open WebUI attribution, model and software licenses | `legal/notices.html` |
| Security policy and `security.txt` | `legal/security.html`, `/.well-known/security.txt` |
| Notice of the documents in the app | banner (`WEBUI_BANNERS` in `openwebui.container`) |
| AI-output disclaimer in the chat | aaru-web `Chat.svelte`, under the composer |

## Agreement and eligibility

- Invite-only; adults only (Terms §1).
- No API key without recorded acceptance: `member.sh add --terms-accepted <date>`
  stores the date and terms version on the key. Keep the member's written
  agreement (for example their email reply).

## Technical controls

| Control | Where |
| --- | --- |
| Security headers: HSTS, CSP (framing, base, objects, forms), X-Frame-Options, nosniff, Referrer-Policy, Permissions-Policy, COOP | `openwebui.container` |
| Branded error pages without internal details; real 404s for unknown API routes; no published API schema | aaru-web `+error.svelte`; `ENV=prod` in the image |
| Not indexed by search engines | `robots.txt` (disallow all), `noindex` on legal and error pages |
| Retention: usage records 90 days without prompt text, logs 30 days, backups up to 12 months | LiteLLM config, `harden-host.sh`, `infra/terraform/backup` |
| Member privacy in the app: no admin chat access or export, no community sharing | `openwebui.container` |
| Access control, encryption in transit, encrypted backups, hardening, audits | see `architecture.md` §4a, §8, §10 |
| Open WebUI License 4(i) user cap (≤ 50 per rolling 30 days) | `verify.sh` (fails above 50), `healthcheck.sh` (alerts above 45) |
| Model provenance and license record | `infra/config/models.catalog`, `.aaru-model.json` per model |
| Secrets kept out of the repository: pre-commit and pre-push gitleaks hooks, CI full-history scan, GitHub push protection, forbidden-file policy | `.githooks/`, `.gitleaks.toml`, `.github/workflows/ci.yml`, `infra/scripts/ci-policy.sh` |
| Supply chain: images by digest, actions by SHA, tools by checksum, Terraform providers by lock file, Dependabot PRs through CI | `ci-policy.sh`, `.github/` |

## Procedures

- Data requests (access, export, correction, deletion): `docs/operations/data-requests.md`
- Incident response and breach notification: `docs/operations/incident-response.md`
- Vulnerability reports: `legal/security.html`

## Before launch

- [ ] Counsel has reviewed the legal pages for your and your members' jurisdictions; `REVIEWED="yes"`.
- [ ] `legal/legal.conf` filled in and pages rendered; `verify.sh` passes the legal and header checks.
- [ ] Every member has accepted the current terms, recorded with `member.sh add --terms-accepted`.
- [ ] Contacts for privacy, security and incidents are monitored mailboxes.
- [ ] A restore drill has passed (`infra/scripts/restore-drill.sh`, spec §10), so the backup retention stated in the Privacy Notice is real.
- [ ] If any member is in the EU or UK: counsel has confirmed the international transfer basis and whether a representative is needed.
- [ ] A reminder to re-render before `security.txt` expires (about 11 months).
