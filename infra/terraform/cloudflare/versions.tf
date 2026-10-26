terraform {
  required_version = ">= 1.10.0"

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.28"
    }
  }
}

provider "cloudflare" {
  # Left null by default so the provider falls back to the
  # CLOUDFLARE_API_TOKEN environment variable. That keeps the token out of
  # terraform.tfvars and out of the state file.
  api_token = var.cloudflare_api_token
}
