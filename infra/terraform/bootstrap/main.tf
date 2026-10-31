# Bootstrap stack: the Terraform state bucket.
#
# This runs with a local backend because a stack cannot create the bucket it
# stores its own state in. Run it once, then point the main stack's backend at
# the bucket it prints.
#
#   cd infra/terraform/bootstrap
#   terraform init
#   terraform apply
#
# The bucket is deliberately plain: versioning on, public access blocked,
# encrypted at rest, no public policy, TLS-only.

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

locals {
  # coalesce skips empty strings, so an unset name falls through to the
  # account-scoped default.
  bucket_name = coalesce(
    var.state_bucket_name,
    "${var.state_bucket_prefix}-${data.aws_caller_identity.current.account_id}",
  )
}

resource "aws_s3_bucket" "state" {
  bucket        = local.bucket_name
  force_destroy = var.force_destroy

  tags = {
    Name    = local.bucket_name
    Purpose = "terraform-state"
  }
}

# The state bucket holds credentials-adjacent material: it contains the
# database URL and other values pulled in by other stacks. Nothing public.
resource "aws_s3_bucket_public_access_block" "state" {
  bucket = aws_s3_bucket.state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# Versioning is what makes a corrupted or overwritten state file recoverable.
resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.state_encryption
      kms_master_key_id = var.state_encryption == "aws:kms" ? var.state_kms_key_arn : null
    }
    bucket_key_enabled = var.state_encryption == "aws:kms"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    id     = "state-retention"
    status = "Enabled"

    # Empty filter: the rule applies to every object in the bucket.
    filter {}

    dynamic "noncurrent_version_expiration" {
      for_each = var.state_noncurrent_expiration_days > 0 ? [1] : []
      content {
        noncurrent_days = var.state_noncurrent_expiration_days
      }
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  depends_on = [aws_s3_bucket_versioning.state]
}

# Refuse plaintext HTTP so the state file never crosses the wire unencrypted.
data "aws_iam_policy_document" "state" {
  statement {
    sid    = "DenyInsecureTransport"
    effect = "Deny"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions   = ["s3:*"]
    resources = [aws_s3_bucket.state.arn, "${aws_s3_bucket.state.arn}/*"]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "state" {
  bucket = aws_s3_bucket.state.id
  policy = data.aws_iam_policy_document.state.json
}
