output "state_bucket_name" {
  description = "Name of the Terraform state bucket."
  value       = aws_s3_bucket.state.id
}

output "state_bucket_arn" {
  description = "ARN of the Terraform state bucket."
  value       = aws_s3_bucket.state.arn
}

output "state_bucket_region" {
  description = "Region of the Terraform state bucket."
  value       = data.aws_region.current.name
}

output "backend_config" {
  description = "Copy these lines into the backend.hcl of each stack that stores state in this bucket."
  value = {
    bucket       = aws_s3_bucket.state.id
    key          = "aaru/terraform.tfstate"
    region       = data.aws_region.current.name
    encrypt      = "true"
    use_lockfile = "true"
  }
}
