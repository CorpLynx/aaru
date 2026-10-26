terraform {
  required_version = ">= 1.10.0"

  required_providers {
    tailscale = {
      source  = "tailscale/tailscale"
      version = "~> 0.29"
    }
  }
}

# Credentials come from the environment, never tfvars: either an API access
# token (TAILSCALE_API_KEY) or an OAuth client (TAILSCALE_OAUTH_CLIENT_ID and
# TAILSCALE_OAUTH_CLIENT_SECRET) with the policy_file and auth_keys scopes.
provider "tailscale" {
  tailnet = var.tailnet
}
