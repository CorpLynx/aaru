# Tailscale stack

Interim member access over Tailscale until the Cloudflare path is live, plus
admin SSH to the host over the tailnet (spec §4a, §9).

| Node | Tag | Who can reach it | What |
| --- | --- | --- | --- |
| `aaru` | `tag:aaru-app` | admins, and anyone the node is shared with | web app on 443, LiteLLM `/v1` on 8443 |
| `aaru-host` | `tag:aaru-host` | admins only | SSH on 22 |

`aaru` is the `tailscale` container (`infra/quadlet/tailscale.container`) on
`aaru-ingress`, the same place as cloudflared: it can reach the web app and
LiteLLM, not PostgreSQL or inference. TLS terminates in that container with a
certificate Tailscale issues for the tailnet name. Members still sign in to the
web app and use their own LiteLLM key; the tailnet only decides who can connect.

The policy is default deny. Neither tagged node can open a connection to
anything else in the tailnet, and members (`autogroup:shared`) get the two app
ports and nothing else.

## Before the first apply

- **The policy replaces the whole tailnet's policy.** If this tailnet already
  has rules (other devices, other people), copy its `groups`, `tagOwners` and
  `acls` into the `extra_*` variables, or give Aaru a tailnet of its own. The
  first apply fails rather than overwrite a non-default policy until you set
  `overwrite_policy = true`.
- In the admin console, under **DNS**: turn on **MagicDNS** and **HTTPS
  Certificates**. The app node's HTTPS serve needs both.
- Credentials: an API access token in `TAILSCALE_API_KEY`, or an OAuth client
  (`TAILSCALE_OAUTH_CLIENT_ID`, `TAILSCALE_OAUTH_CLIENT_SECRET`) with the
  policy file and auth keys scopes.

## Apply and install

```sh
cd infra/terraform/tailscale
cp backend.hcl.example backend.hcl
cp terraform.tfvars.example terraform.tfvars   # admin_logins
terraform init -backend-config=backend.hcl
terraform apply

# App node (as the aaru user on the host)
terraform output -raw app_auth_key | ssh aaru@<host> aaru/infra/scripts/set-tailscale-authkey.sh
ssh aaru@<host> systemctl --user start tailscale.service

# Host node, for admin SSH (as root)
terraform output -raw host_auth_key | ssh <admin>@<host> sudo aaru/infra/scripts/tailscale-host.sh
```

Then, from an SSH session that already comes in over the tailnet, restrict SSH
to it: `sudo infra/scripts/harden-host.sh --admin-user <admin> --ssh-from tailscale0 --apply`.

The auth keys are one-time and expire after `auth_key_expiry_days`. After a
node's first login its own key lives in its state, so the auth key in Terraform
state is spent. Re-apply only if a node has to be re-registered.

## Adding a member

Before the first share: the web app admin must already exist. The first account
created becomes admin even with sign-up off, so create yours over an SSH tunnel
(`ssh -L 3000:127.0.0.1:3000 aaru@<host>`, then `http://localhost:3000`) before
anyone else can reach the app. `verify.sh` fails if the ingress is up without one.

1. Admin console → **Machines** → `aaru` → **Share** → invite the member's
   email (or send the invite link).
2. The member installs Tailscale, signs in with any account of their own and
   accepts. They see only `aaru`; they do not join your tailnet or count as a
   tailnet user.
3. Send them the Terms, Acceptable Use Policy and Privacy Notice
   (`/legal/…`) and get their agreement in writing. Then create their web app
   account (sign-up is off) and their API key, recording that agreement:
   `infra/scripts/member.sh add <email> --terms-accepted <YYYY-MM-DD>`.
4. Point them at the member guide, `https://aaru.<tailnet>.ts.net/legal/guide.html`
   (readable once their share is accepted). They open `https://aaru.<tailnet>.ts.net`. API clients use
   `https://aaru.<tailnet>.ts.net:8443/v1` with their key.

Removing a member: revoke the share (Machines → `aaru` → Share), then
`infra/scripts/member.sh revoke <email>` and remove their web app account.

## Tailnet lock (recommended)

With [tailnet lock](https://tailscale.com/kb/1226/tailnet-lock) on, Tailscale's
coordination server cannot add a node to your tailnet without a signature from
a key you hold. Turn it on from an admin device, then pre-sign each auth key
before installing it: `tailscale lock sign <auth-key>`.

## When Cloudflare is live

```sh
systemctl --user stop tailscale.service
rm ~/.config/containers/systemd/tailscale.container && systemctl --user daemon-reload
```

Remove the `aaru` node in the admin console and the `autogroup:shared` rule in
`main.tf`. Keep `aaru-host`: admin SSH stays on the tailnet.
