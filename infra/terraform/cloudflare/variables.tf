variable "cloudflare_account_id" {
  description = <<-EOT
    Cloudflare account ID (32 hex characters). Zero Trust -> Account ID, or the
    API Tokens page. Set it in terraform.tfvars, which is gitignored, so the
    account is not named in the repository.
  EOT
  type        = string

  validation {
    condition     = can(regex("^[0-9a-f]{32}$", var.cloudflare_account_id))
    error_message = "cloudflare_account_id must be a 32-character hex string."
  }
}

variable "cloudflare_api_token" {
  description = <<-EOT
    Cloudflare API token. Leave null and export CLOUDFLARE_API_TOKEN instead —
    that keeps the token out of terraform.tfvars and out of the state file.

    Required permissions:
      Account  — Cloudflare Tunnel: Edit
      Account  — Zero Trust: Edit
      Zone     — DNS: Edit
      Zone     — Zone: Read
  EOT
  type        = string
  default     = null
  sensitive   = true
}

variable "zone_name" {
  description = "Domain to host in Cloudflare. Set it in terraform.tfvars."
  type        = string
}

variable "tunnel_name" {
  description = "Name of the Cloudflare Tunnel, shown in the Zero Trust dashboard."
  type        = string
  default     = "aaru"
}

variable "create_tunnel" {
  description = <<-EOT
    Create the tunnel with Terraform, or adopt one that already exists.

    true  — Terraform creates the tunnel and reads its connector token, which
            lands in the state file (and therefore in the S3 state bucket).
    false — the tunnel was made in the dashboard and tunnel_id is given
            instead. The connector token stays only in the Podman secret and
            never enters Terraform state. Preferred once the tunnel is stable.
  EOT
  type        = bool
  default     = true
}

variable "tunnel_id" {
  description = "UUID of an existing tunnel. Only used when create_tunnel is false."
  type        = string
  default     = ""

  validation {
    condition = (
      var.tunnel_id == "" ? true :
      can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.tunnel_id))
    )
    error_message = "tunnel_id must be a tunnel UUID, or empty when create_tunnel is true."
  }
}

variable "records" {
  description = <<-EOT
    DNS records to create in the zone for the tunnel. The key is the
    fully-qualified hostname and the value holds the TTL and whether the
    record is proxied.

    Proxied records are flattened to Cloudflare edge addresses at the edge and
    are what a tunnel hostname needs: the traffic has to enter through
    Cloudflare for the tunnel to pick it up.

    ttl 1 means automatic.
  EOT
  type = map(object({
    ttl     = optional(number, 1)
    proxied = optional(bool, true)
  }))
}

variable "ingress" {
  description = <<-EOT
    Public hostnames the tunnel serves, and the service each one reaches.
    The key is the hostname and the value holds the origin service.

    Services are reached over the Podman network, so they use the container
    names: LiteLLM is http://litellm:4000 and the web app is
    http://openwebui:8080. A catch-all rule returning 404 is appended
    automatically.
  EOT
  type = map(object({
    service = string
    path    = optional(string, "")
  }))
}

variable "access_app_name" {
  description = "Name shown in the Access app launcher and on the branded pages."
  type        = string
  default     = "Aaru"
}

variable "access_hostname" {
  description = "Hostname the Access application protects. Must match the hostname in the tunnel's ingress rule and the DNS record."
  type        = string
}

variable "access_member_emails" {
  description = <<-EOT
    Email addresses allowed to reach the hostname. Aaru is invite-only, so
    this is the member list — add a person here when they are invited.

    Each address becomes an Access policy include rule. A user authenticates
    with a one-time PIN sent to that address, so the address is the identity.

    The machine service token is allowed separately, in the same policy.
  EOT
  type        = list(string)
  default     = []
}

variable "access_session_duration" {
  description = "How long an Access session lasts before the user must authenticate again. Cloudflare accepts Go-style durations such as 30m, 8h, 24h."
  type        = string
  default     = "24h"
}

variable "access_service_token_name" {
  description = "Name of the machine credential for scripts and native clients."
  type        = string
  default     = "aaru-api"
}

variable "access_service_token_duration" {
  description = "Lifetime of the machine credential. The maximum is one year."
  type        = string
  default     = "8760h"
}

variable "access_logo_url" {
  description = <<-EOT
    URL of the Aaru mark, used to brand the Access login page and the custom
    denial page. Must be reachable without authentication.
  EOT
  type        = string
  default     = "https://raw.githubusercontent.com/CorpLynx/aaru/main/design/design-system/assets/aaru-mark-white.svg"
}

variable "access_deny_message" {
  description = "Message shown on the custom page when a request is refused."
  type        = string
  default     = "This account does not have access to Aaru."
}

variable "cloudflare_team_name" {
  description = <<-EOT
    Zero Trust organisation name — the first label of your Cloudflare Access
    domain, as in "<team>.cloudflareaccess.com". Zero Trust -> Settings ->
    Account -> Custom Pages shows it, as does the host of the Access login
    page.

    Only used for origin-side token validation, which is off by default.
  EOT
  type        = string
  default     = ""
}

variable "enable_origin_access_validation" {
  description = <<-EOT
    Make cloudflared verify the Access token on the origin as well as at the
    edge, so a request that bypasses Cloudflare is rejected by the origin too.
    This is Cloudflare's "Protect with Access" setting.

    Requires cloudflare_team_name to be correct. If it is wrong, every request
    is rejected at the origin and the application looks unreachable — check
    the cloudflared logs before changing anything else.
  EOT
  type        = bool
  default     = false
}

variable "existing_records" {
  description = <<-EOT
    Records that already serve the domain and have to exist in Cloudflare
    before the delegation moves, or the services behind them break the moment
    Lightsail DNS stops being authoritative.

    Leave it empty for a domain with no records to carry across. The
    variable is here for domains that do: a name can appear more than once
    with different types, which is why this is a list rather than a map.

    For an MX record Cloudflare's content is the mail exchanger on its own;
    the priority is set separately.

    proxied defaults to false so each record keeps the behaviour it has
    today. Only the tunnel records are proxied, because that traffic has to
    enter through the Cloudflare edge for the tunnel to pick it up.

    Drop a record here only after confirming nothing depends on it.
  EOT
  type = list(object({
    name     = string
    type     = string
    content  = string
    proxied  = optional(bool, false)
    priority = optional(number, null)
    ttl      = optional(number, 1)
  }))
  default = []
}
