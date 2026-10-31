output "zone_id" {
  description = "Cloudflare zone ID for the domain."
  value       = cloudflare_zone.this.id
}

output "zone_name_servers" {
  description = <<-EOT
    The nameservers Cloudflare assigned to the zone. Set these at the
    registrar (Gandi) to move the domain over. Until they are set the zone
    stays pending and nothing resolves.
  EOT
  value       = cloudflare_zone.this.name_servers
}

output "zone_pending_nameserver_change" {
  description = "True while the zone is waiting for the registrar's nameservers to be pointed at Cloudflare."
  value       = cloudflare_zone.this.activated_on == null
}

output "tunnel_id" {
  description = "UUID of the Cloudflare Tunnel."
  value       = local.tunnel_id
}

output "tunnel_hostname" {
  description = "CNAME target the DNS records point at."
  value       = local.tunnel_hostname
}

output "tunnel_token" {
  description = <<-EOT
    Connector token for the cloudflared container. Sensitive, and present only
    when create_tunnel is true — in adopt mode the token lives in the Podman
    secret instead.

    Pass it to the host with:
      terraform output -raw tunnel_token \
        | podman secret create cloudflared-token -
  EOT
  value       = try(one(data.cloudflare_zero_trust_tunnel_cloudflared_token.aauru[*].token), null)
  sensitive   = true
}

output "access_service_token_client_id" {
  description = "Client ID of the machine credential for scripts and native clients."
  value       = cloudflare_zero_trust_access_service_token.api.client_id
}

output "access_service_token_client_secret" {
  description = "Client secret of the machine credential. Sensitive, and it bypasses the member list."
  value       = cloudflare_zero_trust_access_service_token.api.client_secret
  sensitive   = true
}

output "published_hostnames" {
  description = "Hostnames the tunnel serves, and the service behind each one."
  value = {
    for hostname, svc in var.ingress :
    hostname => svc.service
  }
}

output "dns_records" {
  description = "Records created in the zone."
  value = {
    for name, record in cloudflare_dns_record.tunnel :
    name => {
      type    = record.type
      content = record.content
      proxied = record.proxied
      ttl     = record.ttl
    }
  }
}
