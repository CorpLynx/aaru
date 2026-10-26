variable "region" {
  description = "AWS region for the state bucket. Must match the region in the stack's backend.hcl."
  type        = string
  default     = "us-east-1"
}

variable "state_bucket_prefix" {
  description = <<-EOT
    Prefix for the Terraform state bucket. The account ID is appended to keep
    the name globally unique, matching the naming used elsewhere in this account.
  EOT
  type        = string
}

variable "state_bucket_name" {
  description = "Explicit bucket name. Leave empty to derive it from state_bucket_prefix and the account ID."
  type        = string
  default     = ""
}

variable "state_encryption" {
  description = "Server-side encryption for state objects: AES256 (SSE-S3) or aws:kms. Keep this in sync with the backend's encrypt/kms_key_id settings."
  type        = string
  default     = "AES256"

  validation {
    condition     = contains(["AES256", "aws:kms"], var.state_encryption)
    error_message = "state_encryption must be AES256 or aws:kms."
  }
}

variable "state_kms_key_arn" {
  description = "KMS key ARN for state encryption. Required when state_encryption is aws:kms; empty means the AWS-managed aws/s3 key. If set, add the same key_id to backend.hcl."
  type        = string
  default     = null
}

variable "state_noncurrent_expiration_days" {
  description = <<-EOT
    Days to keep noncurrent state versions before expiring them. 0 disables
    expiry, which keeps every version recoverable — the safe default for
    state, since expiring versions removes the rollback path.
  EOT
  type        = number
  default     = 0
}

variable "force_destroy" {
  description = "Allow terraform destroy to delete a bucket that still holds state. Keep false — a destroyed state bucket loses the state for every stack that used it."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags applied to the state bucket."
  type        = map(string)
  default = {
    Project   = "aaru"
    ManagedBy = "terraform"
  }
}
