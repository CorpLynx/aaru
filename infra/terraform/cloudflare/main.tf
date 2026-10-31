# Cloudflare owns the zone for Aaru: the DNS records, the tunnel, and the
# tunnel's ingress rules all live here.
#
# The zone is created in Cloudflare and becomes authoritative only after the
# registrar's nameservers are changed to the ones this stack outputs. Until
# that happens the zone is "pending" and its records do not resolve — see
# README.md for the ordering.

locals {
  tunnel_id = var.create_tunnel ? cloudflare_zero_trust_tunnel_cloudflared.aauru[0].id : var.tunnel_id

  # The CNAME target for a tunnel hostname. Cloudflare flattens it to edge
  # addresses for proxied records, so this never appears in public DNS.
  tunnel_hostname = "${local.tunnel_id}.cfargotunnel.com"

  # Cloudflare requires the last ingress rule to be a catch-all.
  #
  # Origin-side Access validation: cloudflared checks the Cf-Access-Jwt-
  # Assertion header itself, so a request that reached the origin without
  # going through Access is refused there as well. It applies to the named
  # hostnames only — the catch-all serves nothing.
  ingress_rules = concat(
    [
      for hostname, svc in var.ingress : merge(
        {
          hostname = hostname
          service  = svc.service
        },
        svc.path == "" ? {} : { path = svc.path },
        var.enable_origin_access_validation ? {
          origin_request = {
            access = {
              aud_tag   = [cloudflare_zero_trust_access_application.aaru.id]
              team_name = var.cloudflare_team_name
              required  = true
            }
          }
        } : {},
      )
    ],
    [
      {
        service = "http_status:404"
      }
    ],
  )
}

resource "cloudflare_zone" "this" {
  account = {
    id = var.cloudflare_account_id
  }

  name   = var.zone_name
  type   = "full"
  paused = false
}

# Remotely managed tunnel: the connector authenticates with a token, the way
# infra/quadlet/cloudflared.container runs `cloudflared tunnel run`.
resource "cloudflare_zero_trust_tunnel_cloudflared" "aauru" {
  count = var.create_tunnel ? 1 : 0

  account_id = var.cloudflare_account_id
  name       = var.tunnel_name

  # "cloudflare" means the ingress rules below are pushed to the dashboard.
  config_src = "cloudflare"
}

# Publishing the hostnames here is what stops Cloudflare's edge answering
# error 1033: without a published hostname the edge has no route for the
# Host header.
resource "cloudflare_zero_trust_tunnel_cloudflared_config" "aauru" {
  account_id = var.cloudflare_account_id
  tunnel_id  = local.tunnel_id
  source     = "cloudflare"

  config = {
    ingress = local.ingress_rules
  }

  lifecycle {
    precondition {
      condition     = local.tunnel_id != ""
      error_message = "Set tunnel_id when create_tunnel is false."
    }
  }
}

resource "cloudflare_dns_record" "tunnel" {
  for_each = var.records

  zone_id = cloudflare_zone.this.id
  name    = each.key
  type    = "CNAME"
  content = local.tunnel_hostname
  ttl     = each.value.ttl
  proxied = each.value.proxied

  comment = "Aaru — Cloudflare Tunnel"

  lifecycle {
    precondition {
      condition     = contains(keys(var.ingress), each.key)
      error_message = "Hostname ${each.key} has a DNS record but no ingress rule. Cloudflare's edge would have no route for it and answer error 1033."
    }
  }
}

# The records the domain already serves, recreated in Cloudflare so nothing
# breaks when the nameservers move. Identity is name plus type, since a name
# can carry several types.
resource "cloudflare_dns_record" "existing" {
  for_each = { for r in var.existing_records : "${r.name}|${r.type}" => r }

  zone_id  = cloudflare_zone.this.id
  name     = each.value.name
  type     = each.value.type
  content  = each.value.content
  ttl      = each.value.ttl
  proxied  = each.value.proxied
  priority = each.value.priority

  comment = "Migrated from Lightsail DNS"
}

# The connector token the cloudflared container runs with. Only read when
# Terraform owns the tunnel; in adopt mode the token stays in the Podman
# secret and never enters the state file.
data "cloudflare_zero_trust_tunnel_cloudflared_token" "aauru" {
  count = var.create_tunnel ? 1 : 0

  account_id = var.cloudflare_account_id
  tunnel_id  = local.tunnel_id
}
