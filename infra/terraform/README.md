# Aaru infrastructure as code

Terraform for the controlled infrastructure around Aaru:

- an S3 bucket in AWS holding Terraform remote state,
- the Cloudflare zone for the domain, the Tunnel that fronts the
  deployment, and the DNS records pointing at it,
- the encrypted backup bucket and its KMS key (see `backup/README.md`), and
- the Tailscale policy and auth keys for interim member access and admin SSH
  (see `tailscale/README.md`).

```
infra/terraform/
├── bootstrap/          # AWS: the S3 state bucket (local backend)
├── cloudflare/         # Cloudflare: zone, DNS records, tunnel, ingress rules
├── backup/             # AWS: backup bucket, KMS key, backup IAM user
└── tailscale/          # Tailscale: tailnet policy, one-time auth keys
```

State lives in AWS; the resources it describes live at Cloudflare. The split
is deliberate — AWS keeps the encrypted-at-rest state and the backups, while
DNS and ingress live where the tunnel lives.

## 1. Bootstrap the state bucket

A stack cannot create the bucket that holds its own state, so the bucket is
built by a separate `bootstrap/` stack that runs with a local backend. Run it
once per account; the other stack then points its backend at the result.

This is a two-phase run, because Terraform will not `apply` with an
uninitialised backend — and the bucket's own backend is S3, which does not
exist yet:

```sh
cd infra/terraform/bootstrap

# Phase 1 — comment out the `backend "s3" {}` block in versions.tf, then:
terraform init
terraform apply

# Phase 2 — put the backend block back, then:
cp backend.hcl.example backend.hcl
terraform init -migrate-state -force-copy -backend-config=backend.hcl
```

Use `-force-copy` rather than answering the prompt. Piping `yes` into
`terraform init` does not work — the prompt is read twice and the state ends
up truncated rather than copied. If that happens, the original is still in
`terraform.tfstate.backup` and can be pushed with
`terraform state push terraform.tfstate`.

The bucket has versioning on, public access blocked, SSE-S3 encryption,
`BucketOwnerEnforced` ownership, a policy denying plaintext HTTP, and no
destroy path — deleting a state bucket loses the state for every stack that
used it.

State layout in the bucket:

| Key | Holds |
| --- | --- |
| `aaru/bootstrap/terraform.tfstate` | The bucket itself |
| `aaru/cloudflare/terraform.tfstate` | The zone, tunnel, records and connector token |

The keys are examples. An existing deployment keeps the keys its `backend.hcl`
already uses; changing a key points Terraform at an empty state.

The bootstrap stack's own state lives in the bucket it manages. That is
circular but safe: the bucket is versioned and the state is one small object.
If the bucket is ever lost, the bootstrap stack can be re-applied and the
other stacks re-imported.

## 2. Move the zone to Cloudflare

The steps below assume the domain is registered through **Amazon Lightsail**
and served by **Lightsail DNS** — a simplified zone that Lightsail keeps on a
Route 53 hosted zone of its own, which is why such a domain does not appear
in `aws route53 list-hosted-zones`.

If the domain has no public records, moving it is a nameserver change and
nothing else. Otherwise list them in `existing_records` first.

### Create an API token

In the Cloudflare dashboard: **My Profile → API Tokens → Create Token**, with
these permissions:

| Scope | Permission |
| --- | --- |
| Account | Cloudflare Tunnel: Edit |
| Account | Cloudflare Tunnel: Read |
| Zone | DNS: Edit |
| Zone | DNS: Read |
| Zone | Zone Settings: Read |

Zone permissions are scoped to `example.com`. Set **Zone Resources** to
All zones for the first apply — the zone does not exist yet, so a filter
naming it may not match on create. Tighten it afterwards.

The Cloudflare account ID, the domain and the hostnames go in
`cloudflare/terraform.tfvars`, which is gitignored, so none of them are
named in the repository.

### Apply the Cloudflare stack

```sh
cd infra/terraform/cloudflare
cp backend.hcl.example backend.hcl        # set bucket, key and region
cp terraform.tfvars.example terraform.tfvars

export CLOUDFLARE_API_TOKEN='...'          # keeps the token out of .tfvars
terraform init -migrate-state -force-copy -backend-config=backend.hcl
terraform plan
terraform apply
```

This creates the zone, the tunnel, the tunnel's ingress rules, and the Aaru
record.

The stack needs a `backend "s3" {}` block in `cloudflare/backend.tf` for
`-backend-config` to mean anything. Without it Terraform only warns
*"Missing backend configuration"* and quietly keeps using the local backend.

### Point the domain at Cloudflare

Lightsail lets you hand a domain to another DNS provider, and the console
does it under **Domains & DNS → example.com → Edit Name Servers**. The
Lightsail API has no operation for this — `create-domain`,
`create/update/delete-domain-entry` and `get-domain(s)` are all it offers.

The delegation itself is reachable through the **Route 53 Domains** API,
because Lightsail domains are registered there:

```sh
aws route53domains update-domain-nameservers --cli-input-json '{
  "DomainName": "example.com",
  "Nameservers": [
    {"Name": "<ns-1>.ns.cloudflare.com"},
    {"Name": "<ns-2>.ns.cloudflare.com"}
  ]
}'
```

Note that `--nameservers Name=a,Name=b` does not work — the list shorthand
cannot repeat a key, so it fails with *"Second instance of key Name
encountered"*. Use `--cli-input-json`.

The change is processed asynchronously: `get-domain-detail` keeps showing the
old nameservers for a few seconds after the call returns an operation ID, and
the registry takes minutes to hours to publish the new delegation.

To undo it, put the original nameservers back:

```sh
aws route53domains get-domain-detail --domain-name example.com \
  --query 'Nameservers[].Name' --output text
```

### Install the connector token on the host

```sh
infra/scripts/set-cloudflared-token.sh
systemctl --user restart cloudflared.service
```

The script reads the token from Terraform output and pipes it straight into a
Podman secret, so it never touches a file or the shell history.

### Verify

```sh
curl -sS -o /dev/null -w '%{http_code}\n' https://aaru.example.com/health
```

A `200` means the whole path works: delegation → Cloudflare edge → tunnel →
LiteLLM.

## The pieces this stack manages

**Zone** (`cloudflare_zone`) — `example.com`, type `full`. Its
`name_servers` output is what goes into the delegation.

**Tunnel** (`cloudflare_zero_trust_tunnel_cloudflared`) — a remotely managed
tunnel (`config_src = "cloudflare"`), which is what
`infra/quadlet/cloudflared.container` expects: the connector authenticates
with a token and the ingress rules live in the dashboard.

**Ingress rules** (`cloudflare_zero_trust_tunnel_cloudflared_config`) — which
hostname reaches which service. This is the piece that stops Cloudflare's
edge answering error 1033: without a published hostname the edge has no route
for the Host header. Services are Podman container names on
`aaru-ingress.network`, so LiteLLM is `http://litellm:4000` and the web app
is `http://openwebui:8080`. A catch-all 404 rule is appended automatically.

**Aaru record** (`cloudflare_dns_record.tunnel`) — a proxied CNAME pointing
at `<tunnel-id>.cfargotunnel.com`. Proxied is what routes the traffic
through the edge, where the tunnel can pick it up. The zone then gets a
Universal SSL certificate covering the hostname, which is why the domain
needs to be in Cloudflare rather than only pointed at it.

**Migrated records** (`cloudflare_dns_record.existing`) — empty for a
domain with no records to carry across. The variable is there for when a
domain does: it holds records that already serve the domain
and have to exist in Cloudflare before the delegation moves, or the services
behind them break the moment Lightsail DNS stops being authoritative. A
record name can appear more than once with different types, which is why it
is a list rather than a map.

## Recovering from a failed apply

When an apply fails, Terraform cancels the record creations that were still in
flight — but Cloudflare may have completed them server-side. Those records
then exist in the zone without being in state, and the next apply fails with
`81058 An identical record already exists` or `81053 An A, AAAA, or CNAME
record with that host already exists`.

`reconcile-records.sh` finds them and imports them:

```sh
cd infra/terraform/cloudflare
./reconcile-records.sh                   # list what would be imported or pruned
./reconcile-records.sh --apply           # import the orphans
./reconcile-records.sh --prune           # delete the records this stack dropped
```

It compares the records in the zone against the planned resources and the
current state, so it only touches records this stack owns. `--prune` deletes
records that are in the zone but that the configuration no longer lists. It
asks for confirmation first and lists every record it is about to delete. It
also prints the zone's nameservers at the end.

Two things it catches that a name-and-type match alone would miss:

- **Orphans** — a record this stack owns that exists in the zone but is not
  in state, because a failed apply orphaned the create.
- **Duplicates** — a stale copy of a record we track, same name and type but
  a different value. Cloudflare runs a DNS scan when a zone is created and
  imports the existing records; for TXT values the scanned copies keep their
  quotes, so the scanned and created copies differ and both end up in the
  zone. Only one is served, but the other should go.

## Access: the identity layer

A tunnel is a path, not a gate. It hides the origin — no inbound ports, nothing
listening on the public internet — but it makes no decision about who may use
it. Cloudflare's own documentation says it plainly: *"If you do not have an
Access application in place, the published application will be available to
anyone on the Internet."*

Access closes that gap. It intercepts at Cloudflare's edge, **before** the
tunnel, so an unauthenticated request never reaches your host at all.

Two gates in series:

```
browser  →  Access (one-time PIN to a member address)  →  LiteLLM (virtual key)
script   →  Access (service token)                      →  LiteLLM (virtual key)
```

**Members.** `access_member_emails` is the allowlist. Each address
authenticates with a one-time PIN sent to that address, so the address is the
identity — no password to store, no IdP to run. Add a person by adding their
address to the list and applying.

**Machines.** `cloudflare_zero_trust_access_service_token.api` is a shared
credential for clients that cannot do a browser login. It is allowed by the
same policy, so it bypasses the member list — treat it like a password:

```sh
curl -H "CF-Access-Client-Id: $(terraform output -raw access_service_token_client_id)" \
     -H "CF-Access-Client-Secret: $(terraform output -raw access_service_token_client_secret)" \
     https://aaru.example.com/v1/models
```

**Why this sits in front of LiteLLM's own auth.** LiteLLM's auth layer breaks
often — this stack's advisory history includes an authentication bypass via
Host header injection (`CVE-2026-49468`), one via an OIDC userinfo cache-key
collision (`CVE-2026-35030`), and a salt-key reuse issue that escalates
`internal_user` to `proxy_admin` and then to command execution
(`CVE-2026-114612`). A public endpoint gated only by that auth is one bug away
from being an open proxy with SSRF into the podman network. Access is a
separate control plane, so it does not share the failure mode.

**Branding.** The login page uses `logo_url` from the Aaru design tokens.
Users who are refused land on a custom page (`deny-page.html`) built from the
same palette. The custom page is legacy custom HTML served verbatim, which is
safe because it carries no form — the login page itself is branded through
the application resource, not through a custom template, because a login page
served verbatim would have no form in it.

**Origin-side validation** is opt-in (`enable_origin_access_validation`).
It makes cloudflared verify the Access token at the origin as well, so a
request that bypasses Cloudflare is rejected there too — Cloudflare's
"Protect with Access" setting. It needs `cloudflare_team_name`, the first
label of your Access domain (`<team>.cloudflareaccess.com`). If that name is
wrong every request is refused at the origin and the application looks
unreachable, so it stays off until the tunnel is working.

**The API token needs more scope.** Managing Access requires **Account →
Access: Apps and Policies → Edit** and **Read**, on top of the tunnel and DNS
permissions. A token without them gets a 403 on every Access resource.

## Keeping the connector token out of state

With `create_tunnel = true`, Terraform reads the tunnel's connector token
from the Cloudflare API, so the token is written to the state file in the S3
bucket. The bucket is encrypted and private, but it is still a copy of a
credential in a place the spec would rather not have one.

Once the tunnel is stable, switch to adopt mode: set `create_tunnel = false`
and pass `tunnel_id`. Terraform then manages only the ingress rules and DNS,
the token stays in the Podman secret, and nothing else changes.

The state bucket uses SSE-S3 today. The AWS-managed `aws/s3` KMS key would
add CloudTrail audit records on every state decrypt, which is worth having
for a bucket holding a credential:

```sh
# in bootstrap/: state_encryption = "aws:kms", then terraform apply
# in backend.hcl: add kms_key_id = "alias/aws/s3"
```

Both sides have to agree, or the backend cannot read what it writes.

## Changing things

| Change | How |
| --- | --- |
| Add a hostname | Add it to `records` and `ingress` in `terraform.tfvars`, apply, then publish the matching public hostname on the tunnel. |
| Point a hostname at the web app | Give it a service of `http://openwebui:8080`. |
| Move to a new tunnel | Change `tunnel_id` with `create_tunnel = false`, apply. |
| Rotate the connector token | In the dashboard, or delete the secret and re-run `set-cloudflared-token.sh`. |
| Rotate the state bucket | Recreate it in `bootstrap/` and update `backend.hcl`, then `terraform init -migrate-state -backend-config=backend.hcl`. |
| Use KMS instead of SSE-S3 for state | Set `state_encryption = "aws:kms"` in the bootstrap stack and add the same `kms_key_id` to `backend.hcl`. The two must agree or the backend cannot read what it writes. |

## Two caveats about `terraform destroy`

`cloudflare_zero_trust_tunnel_cloudflared_config` cannot be destroyed by
Terraform — the provider warns about this during plan. The ingress rules stay
on the tunnel in the API until they are removed by hand, so a destroy leaves
the tunnel serving whatever it was last configured with.

Destroying the zone removes the DNS records, but the tunnel itself is a
separate resource. Deleting the zone while the domain is still delegated to
Cloudflare leaves the domain resolving against an empty zone.

## Related, not created here

The spec's encrypted backup bucket (§8, SSE-KMS with a customer-managed KMS
key, object lock, lifecycle rules) is a different bucket from the state
bucket — the backup bucket holds encrypted PostgreSQL dumps and is written by
`infra/scripts/backup.sh` with `AARU_S3_BUCKET` and `AARU_KMS_KEY_ARN`. It is
not part of this stack.
