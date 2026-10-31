variable "tailnet" {
  description = "Tailnet name or ID. \"-\" means the tailnet the credentials belong to."
  type        = string
  default     = "-"
}

variable "admin_logins" {
  description = "Tailscale logins (e.g. email addresses) of the Aaru admins: SSH to the host and owners of the Aaru tags."
  type        = list(string)

  validation {
    condition     = length(var.admin_logins) > 0
    error_message = "At least one admin login is required."
  }
}

variable "overwrite_policy" {
  description = <<-EOT
    The tailnet policy is one document for the whole tailnet; applying this
    stack replaces it. Leave false: the first apply then fails if the tailnet
    already has a non-default policy, instead of silently dropping its rules.
    Carry those rules over in the extra_* variables (or use a tailnet only for
    Aaru), then set true.
  EOT
  type        = bool
  default     = false
}

variable "extra_groups" {
  description = "Groups from the existing tailnet policy to keep, as in the policy file's groups section."
  type        = map(list(string))
  default     = {}
}

variable "extra_tag_owners" {
  description = "Tag owners from the existing tailnet policy to keep."
  type        = map(list(string))
  default     = {}
}

variable "extra_acls" {
  description = "ACL rules from the existing tailnet policy to keep, each {action, src, dst}."
  type        = list(any)
  default     = []
}

variable "auth_key_expiry_days" {
  description = "Lifetime of the one-time auth keys. They are needed only for the first login of each node."
  type        = number
  default     = 7
}
