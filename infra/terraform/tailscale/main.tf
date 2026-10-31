# Interim member access over Tailscale until the Cloudflare path is live (spec §9).
#
#   tag:aaru-app   the tailscale container on aaru-ingress: web app on 443,
#                  LiteLLM /v1 on 8443. Members reach it through node sharing.
#   tag:aaru-host  the Fedora host's own tailscaled: SSH for admins only.
#
# Default deny: anything not allowed below is dropped, and neither tagged node
# can start a connection to anything else on the tailnet.

locals {
  policy = {
    groups = merge(var.extra_groups, {
      "group:aaru-admins" = var.admin_logins
    })

    tagOwners = merge(var.extra_tag_owners, {
      "tag:aaru-app"  = ["group:aaru-admins"]
      "tag:aaru-host" = ["group:aaru-admins"]
    })

    acls = concat(var.extra_acls, [
      {
        # Admins: SSH to the host, and the app like any member.
        action = "accept"
        src    = ["group:aaru-admins"]
        dst    = ["tag:aaru-host:22", "tag:aaru-app:443,8443"]
      },
      {
        # Members: anyone who accepted a share of the aaru node, app ports only.
        # Sharing gives them that one node and nothing else in the tailnet.
        action = "accept"
        src    = ["autogroup:shared"]
        dst    = ["tag:aaru-app:443,8443"]
      },
    ])

    tests = [
      {
        src    = var.admin_logins[0]
        accept = ["tag:aaru-host:22", "tag:aaru-app:443", "tag:aaru-app:8443"]
        deny   = ["tag:aaru-host:8088", "tag:aaru-app:22"]
      },
    ]
  }
}

resource "tailscale_acl" "this" {
  acl                        = jsonencode(local.policy)
  overwrite_existing_content = var.overwrite_policy
}

# One-time, pre-authorized, tagged keys: each logs in one node, then is spent.
resource "tailscale_tailnet_key" "app" {
  description   = "aaru-app (tailscale container)"
  reusable      = false
  ephemeral     = false
  preauthorized = true
  expiry        = var.auth_key_expiry_days * 86400
  tags          = ["tag:aaru-app"]

  depends_on = [tailscale_acl.this]
}

resource "tailscale_tailnet_key" "host" {
  description   = "aaru-host (host tailscaled, admin SSH)"
  reusable      = false
  ephemeral     = false
  preauthorized = true
  expiry        = var.auth_key_expiry_days * 86400
  tags          = ["tag:aaru-host"]

  depends_on = [tailscale_acl.this]
}
