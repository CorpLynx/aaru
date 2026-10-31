# Incident response

For anything that may affect the security of Aaru or members' data: a
vulnerability report, an alert, a leaked key, unexpected access, data loss.
Write down what you do and when, as you go; you may need the timeline later.

## 1. Contain (first hour)

Pick what fits; containment comes before investigation.

| Situation | Action |
| --- | --- |
| Active attack or unknown access | Stop member ingress: `systemctl --user stop tailscale.service cloudflared.service` |
| Leaked member key | `infra/scripts/member.sh rotate <email>` (or `revoke`) |
| Leaked master key, DB password, tunnel token or auth key | Create a new Podman secret, restart the services that use it, revoke the old one at its source (Cloudflare, Tailscale, AWS) |
| Compromised web app account | Admin → Users → reset or disable the account |
| Suspected host compromise | Disconnect member ingress, keep the host running for evidence, do not reinstall yet |

## 2. Preserve evidence

Before changing more, copy what you will need, to storage the host cannot
modify:

```sh
journalctl --since "-7 days" -o export > journal.export        # as root
podman logs --since 168h <container> > <container>.log           # per container
sudo ausearch -ts recent > audit.log
podman ps -a; podman inspect <container> > <container>.inspect.json
```

Logs are kept 30 days, so do this early.

## 3. Assess

- What happened, when it started, how it got in, what it touched.
- Was personal data accessed, changed, lost or disclosed? Whose, and what kind
  (account details, chat content, files)?
- Is it still happening?

## 4. Notify

Get legal advice early if personal data may be involved; deadlines start when
you become aware of the breach.

- **Members affected**: tell them without undue delay what happened, what data
  was involved, what you have done and what they should do (for example rotate
  keys or passwords).
- **Data protection authority**: if any affected member is in the EU or UK and
  the breach is likely to put them at risk, notify the authority within
  **72 hours** of becoming aware (GDPR Art. 33).
- **US state breach laws**: notification duties and deadlines vary by state and
  depend on the type of data; counsel decides.
- **Upstream projects**: report vulnerabilities in their software to them
  (Open WebUI, LiteLLM, llama.cpp, llama-swap) privately.
- **Reporter**: if the incident started with a vulnerability report, keep them
  updated (Security policy).

## 5. Recover

Fix the cause, rebuild from known-good, digest-pinned images, restore data from
backup if needed (`infra/terraform/backup/README.md`), rotate every credential
the attacker could have seen, and run `verify.sh` before re-enabling ingress.

## 6. Review

Within two weeks: write up the timeline, root cause and what changes, and make
the changes. Keep the write-up with the incident record.

## Contacts

Keep current, in your own records, not in this public repository: the operator,
counsel, the hosting and network providers' abuse contacts, and the relevant
data protection authority.
