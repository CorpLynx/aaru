# Legal pages

Templates for the documents members see, served by the web app without sign-in:

| Page | Path |
| --- | --- |
| Member guide (getting in, models, API, data, help) | `/legal/guide.html` |
| Terms of Service (with the AI-output disclaimer) | `/legal/terms.html` |
| Acceptable Use Policy | `/legal/acceptable-use.html` |
| Privacy Notice | `/legal/privacy.html` |
| Third-party notices (software and model licenses) | `/legal/notices.html` |
| Security policy (vulnerability reporting) | `/legal/security.html` |
| security.txt ([RFC 9116](https://www.rfc-editor.org/rfc/rfc9116)) | `/.well-known/security.txt` |

**These are starting points, not legal advice.** They were written to match how
this deployment actually handles data, but whether they are enough depends on
where you and your members are. Have counsel in your jurisdiction review them,
then set `REVIEWED="yes"`. Until then every page carries a visible DRAFT banner
and `verify.sh` warns.

## Render and serve

```sh
cp legal/legal.conf.example legal/legal.conf   # operator name, contacts, jurisdiction, URL
infra/scripts/render-legal.sh                  # writes legal/site/ (gitignored)
```

`openwebui.container` mounts `legal/site` at `/app/build/legal` and its
`.well-known` at `/app/build/.well-known`. Rendering updates the files in
place, so the running app serves new versions immediately.

## When the documents change

1. Edit the templates, bump `TERMS_VERSION` and `EFFECTIVE_DATE` in `legal.conf`,
   and re-render.
2. Change the banner `id` in `openwebui.container` (`WEBUI_BANNERS`) so every
   member sees the notice again, and restart the web app.
3. Tell members about material changes before the effective date (Terms §11,
   Privacy §8), and record each member's acceptance of the new version.

## Keep the documents true

The Privacy Notice states facts the deployment enforces. If you change any of
these, change the notice in the same commit:

| Statement | Enforced by |
| --- | --- |
| Usage records hold no prompt text and are kept 90 days | `infra/config/litellm/config.yaml` (`store_prompts_in_spend_logs`, `maximum_spend_logs_retention_period`) |
| Technical logs are kept 30 days | `harden-host.sh` (journald `MaxRetentionSec`) |
| Backups: daily 31 days, weekly 12 weeks, monthly 12 months | `infra/terraform/backup` (`retention`) |
| Admins cannot open or export members' chats in the app | `openwebui.container` (`ENABLE_ADMIN_CHAT_ACCESS`, `ENABLE_ADMIN_EXPORT`) |
| No chat sharing to third parties | `openwebui.container` (`ENABLE_COMMUNITY_SHARING`) |
| Models run locally; no data to model developers | llama-swap on the internal network, which has no egress |
| Who else is involved (Tailscale, Cloudflare, AWS) | `infra/quadlet`, `infra/terraform` |
| Members are adults and accepted the terms | `member.sh add --terms-accepted` records date and version on the key |

`security.txt` expires about 11 months after rendering; re-render before then
(`verify.sh` warns 30 days ahead).
