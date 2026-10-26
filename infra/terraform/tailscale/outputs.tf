output "app_auth_key" {
  description = "One-time key for the tailscale container. Install with infra/scripts/set-tailscale-authkey.sh."
  value       = tailscale_tailnet_key.app.key
  sensitive   = true
}

output "host_auth_key" {
  description = "One-time key for the host's tailscaled. Install with infra/scripts/tailscale-host.sh."
  value       = tailscale_tailnet_key.host.key
  sensitive   = true
}
