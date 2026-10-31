# Backup stack: the encrypted off-host backup target (spec §10).
#
#   - an S3 bucket with versioning, Object Lock and lifecycle rules per prefix
#   - a customer-managed KMS key that only the backup user can use
#   - an IAM user with write and read access to that bucket and key only
#
# The user's access key is not created here, so it never lands in state. See
# README.md for creating it and installing it on the host.

data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

locals {
  account_id  = data.aws_caller_identity.current.account_id
  bucket_name = coalesce(var.bucket_name, "${var.bucket_prefix}-${local.account_id}")
  root_arn    = "arn:${data.aws_partition.current.partition}:iam::${local.account_id}:root"
}

# --- Identity ---------------------------------------------------------------

resource "aws_iam_user" "backup" {
  name = var.backup_user_name
  path = "/aaru/"
}

# --- KMS --------------------------------------------------------------------

# The account root can administer the key (so it can never be orphaned) but
# cannot use it: encrypt and decrypt belong to the backup user alone.
data "aws_iam_policy_document" "kms" {
  statement {
    sid    = "AccountAdministersKey"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = [local.root_arn]
    }
    actions = [
      "kms:Create*", "kms:Describe*", "kms:Enable*", "kms:List*", "kms:Put*",
      "kms:Update*", "kms:Revoke*", "kms:Disable*", "kms:Get*", "kms:Delete*",
      "kms:TagResource", "kms:UntagResource",
      "kms:ScheduleKeyDeletion", "kms:CancelKeyDeletion",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "BackupUserUsesKey"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = [aws_iam_user.backup.arn]
    }
    actions = [
      "kms:Encrypt", "kms:Decrypt", "kms:ReEncrypt*",
      "kms:GenerateDataKey*", "kms:DescribeKey",
    ]
    resources = ["*"]
  }
}

resource "aws_kms_key" "backup" {
  description             = "Aaru backup encryption (SSE-KMS)"
  enable_key_rotation     = true
  deletion_window_in_days = 30
  policy                  = data.aws_iam_policy_document.kms.json
}

resource "aws_kms_alias" "backup" {
  name          = "alias/${var.backup_user_name}"
  target_key_id = aws_kms_key.backup.key_id
}

# --- Bucket -----------------------------------------------------------------

resource "aws_s3_bucket" "backup" {
  bucket = local.bucket_name

  # Object Lock can only be turned on when the bucket is created.
  object_lock_enabled = true
  force_destroy       = false
}

resource "aws_s3_bucket_public_access_block" "backup" {
  bucket = aws_s3_bucket.backup.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "backup" {
  bucket = aws_s3_bucket.backup.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_versioning" "backup" {
  bucket = aws_s3_bucket.backup.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "backup" {
  bucket = aws_s3_bucket.backup.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.backup.arn
    }
    bucket_key_enabled = true
  }
}

# Every object version is locked for the retention period: nobody, including
# the backup user, can delete or overwrite it until the period ends.
resource "aws_s3_bucket_object_lock_configuration" "backup" {
  bucket = aws_s3_bucket.backup.id

  rule {
    default_retention {
      mode = var.object_lock_mode
      days = var.object_lock_days
    }
  }

  depends_on = [aws_s3_bucket_versioning.backup]
}

# Retention per prefix (spec §10: 30 days daily, 12 weeks weekly, 12 months
# monthly). Expiry adds a delete marker; the locked version itself is removed
# by the noncurrent rule once its lock has run out.
resource "aws_s3_bucket_lifecycle_configuration" "backup" {
  bucket = aws_s3_bucket.backup.id

  dynamic "rule" {
    for_each = var.retention
    content {
      id     = rule.key
      status = "Enabled"

      filter {
        prefix = "${rule.key}/"
      }

      dynamic "transition" {
        for_each = rule.value.glacier_after_days > 0 ? [1] : []
        content {
          days          = rule.value.glacier_after_days
          storage_class = "GLACIER_IR"
        }
      }

      expiration {
        days = rule.value.expire_after_days
      }

      noncurrent_version_expiration {
        noncurrent_days = 1
      }

      abort_incomplete_multipart_upload {
        days_after_initiation = 2
      }
    }
  }

  depends_on = [aws_s3_bucket_versioning.backup]
}

data "aws_iam_policy_document" "bucket" {
  statement {
    sid    = "DenyInsecureTransport"
    effect = "Deny"
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    actions   = ["s3:*"]
    resources = [aws_s3_bucket.backup.arn, "${aws_s3_bucket.backup.arn}/*"]
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  # Writes must name this stack's KMS key, never SSE-S3 or another key.
  statement {
    sid    = "DenyOtherEncryptionKeys"
    effect = "Deny"
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.backup.arn}/*"]
    condition {
      test     = "StringNotEqualsIfExists"
      variable = "s3:x-amz-server-side-encryption-aws-kms-key-id"
      values   = [aws_kms_key.backup.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "backup" {
  bucket = aws_s3_bucket.backup.id
  policy = data.aws_iam_policy_document.bucket.json

  depends_on = [aws_s3_bucket_public_access_block.backup]
}

# --- Backup user permissions ------------------------------------------------

# Write, read back and list; no delete, no lock changes, nothing else.
data "aws_iam_policy_document" "user" {
  statement {
    sid       = "ListBucket"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.backup.arn]
  }

  statement {
    sid = "ReadWriteObjects"
    actions = [
      "s3:PutObject", "s3:GetObject", "s3:GetObjectAttributes",
      "s3:AbortMultipartUpload", "s3:ListMultipartUploadParts",
    ]
    resources = ["${aws_s3_bucket.backup.arn}/*"]
  }

  statement {
    sid       = "UseBackupKey"
    actions   = ["kms:Encrypt", "kms:Decrypt", "kms:GenerateDataKey*", "kms:DescribeKey"]
    resources = [aws_kms_key.backup.arn]
  }
}

resource "aws_iam_user_policy" "backup" {
  name   = "aaru-backup"
  user   = aws_iam_user.backup.name
  policy = data.aws_iam_policy_document.user.json
}
