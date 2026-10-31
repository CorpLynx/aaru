terraform {
  # The state for the bucket that holds everyone's state. Chicken and egg:
  # a stack cannot create the bucket it stores its own state in, so the
  # first run uses -backend=false and keeps state locally. Once the bucket
  # exists, migrate into it:
  #
  #   terraform init -backend=false
  #   terraform apply
  #   terraform init -migrate-state -backend-config=backend.hcl
  #
  backend "s3" {}

  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.70"
    }
  }
}
