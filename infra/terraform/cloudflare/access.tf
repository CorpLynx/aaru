# Cloudflare Access — the identity layer in front of the tunnel.
#
# A tunnel is a path, not a gate. Publishing a hostname makes it reachable by
# anyone who finds it; Access decides who gets through, at Cloudflare's edge,
# before the request ever reaches the host.
#
# Two gates, in series:
#   browser / native app  ->  Access (identity)  ->  LiteLLM (virtual key)
#   script / machine      ->  Access (service token) -> LiteLLM (virtual key)

# --- Machine credential ---------------------------------------------------
# A shared secret for clients that cannot do a browser login. Treat it like
# a password: it bypasses the member allowlist, so anyone holding it reaches
# the hostname.
resource "cloudflare_zero_trust_access_service_token" "api" {
  account_id = var.cloudflare_account_id
  name       = var.access_service_token_name
  duration   = var.access_service_token_duration
}

# --- Branded page for users who are refused -------------------------------
# Legacy custom HTML is served verbatim, which is safe here because this page
# has no form in it. The login page is branded through the application's logo
# and colours instead — see the application resource below.
resource "cloudflare_zero_trust_access_custom_page" "forbidden" {
  account_id = var.cloudflare_account_id
  name       = "${var.access_app_name} denied"
  type       = "forbidden"

  custom_html = templatefile("${path.module}/deny-page.html", {
    logo_url = var.access_logo_url
    title    = var.access_app_name
    message  = var.access_deny_message
  })
}

# --- The application ------------------------------------------------------
resource "cloudflare_zero_trust_access_application" "aaru" {
  account_id = var.cloudflare_account_id
  name       = var.access_app_name
  domain     = var.access_hostname
  type       = "self_hosted"

  # How long an Access session lasts before the user is asked to authenticate
  # again. Cloudflare checks the token on every request, so an expired session
  # is re-authenticated mid-use rather than at the next page load.
  session_duration = var.access_session_duration

  # Branding for the Access login page, from the Aaru design tokens. The
  # App Launcher's own logo and background colours belong to an
  # app_launcher-type application and are rejected on a self-hosted one.
  logo_url             = var.access_logo_url
  app_launcher_visible = true

  # Cookie hardening. The binding cookie ties the session to the browser that
  # created it, which blunts a stolen CF_Authorization cookie.
  http_only_cookie_attribute = true
  same_site_cookie_attribute = "lax"
  enable_binding_cookie      = true

  # A machine client with a bad or missing service token gets a 401 rather
  # than a redirect to a login page it cannot follow.
  service_auth_401_redirect = true

  custom_pages        = [cloudflare_zero_trust_access_custom_page.forbidden.id]
  custom_deny_message = "You do not have access to Aaru. Ask an operator for an invitation."

  policies = [
    {
      name             = "Members"
      decision         = "allow"
      precedence       = 1
      session_duration = var.access_session_duration

      # Include rules are OR'd: any one of these lets the request through.
      include = concat(
        [for email in var.access_member_emails : { email = { email = email } }],
        [{ service_token = { token_id = cloudflare_zero_trust_access_service_token.api.id } }],
      )
    },
  ]
}
