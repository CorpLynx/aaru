variable "region" {
  description = "AWS region for the backup bucket and KMS key."
  type        = string
}

variable "bucket_prefix" {
  description = "Prefix for the backup bucket. The account ID is appended to keep the name globally unique."
  type        = string
}

variable "bucket_name" {
  description = "Explicit bucket name. Leave empty to derive it from bucket_prefix and the account ID."
  type        = string
  default     = ""
}

variable "backup_user_name" {
  description = "IAM user the host's backup job authenticates as. Also names the KMS alias."
  type        = string
  default     = "aaru-backup"
}

variable "object_lock_mode" {
  description = <<-EOT
    Object Lock mode for every backup version. GOVERNANCE lets an account
    administrator with s3:BypassGovernanceRetention remove a version early;
    COMPLIANCE lets nobody, including the root user, until retention ends.
    Spec §10 asks for COMPLIANCE. Switch once a restore drill has passed,
    because a mistake made under COMPLIANCE cannot be undone.
  EOT
  type        = string
  default     = "GOVERNANCE"

  validation {
    condition     = contains(["GOVERNANCE", "COMPLIANCE"], var.object_lock_mode)
    error_message = "object_lock_mode must be GOVERNANCE or COMPLIANCE."
  }
}

variable "object_lock_days" {
  description = "Days each backup version is locked. Must not exceed the shortest expire_after_days in retention."
  type        = number
  default     = 30
}

variable "retention" {
  description = <<-EOT
    Lifecycle per prefix. backup.sh writes every run to daily/, and copies the
    Sunday run to weekly/ and the run on the 1st to monthly/. glacier_after_days
    of 0 keeps the objects in S3 Standard.
  EOT
  type = map(object({
    expire_after_days  = number
    glacier_after_days = number
  }))
  default = {
    daily   = { expire_after_days = 31, glacier_after_days = 0 }
    weekly  = { expire_after_days = 84, glacier_after_days = 0 }
    monthly = { expire_after_days = 366, glacier_after_days = 30 }
  }

  validation {
    condition     = alltrue([for r in values(var.retention) : r.glacier_after_days == 0 || r.glacier_after_days < r.expire_after_days])
    error_message = "glacier_after_days must be 0 or less than expire_after_days."
  }
}
