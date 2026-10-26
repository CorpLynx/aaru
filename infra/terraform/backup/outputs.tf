output "bucket_name" {
  description = "Backup bucket; pass to set-backup-credentials.sh --bucket."
  value       = aws_s3_bucket.backup.id
}

output "kms_key_arn" {
  description = "Backup KMS key; pass to set-backup-credentials.sh --kms-key-arn."
  value       = aws_kms_key.backup.arn
}

output "region" {
  description = "Region of the bucket and key; pass to set-backup-credentials.sh --region."
  value       = var.region
}

output "backup_user_name" {
  description = "IAM user to create an access key for."
  value       = aws_iam_user.backup.name
}

output "install_command" {
  description = "Run from a machine with admin AWS credentials to give the host its key."
  value       = "aws iam create-access-key --user-name ${aws_iam_user.backup.name} --output json | ssh aaru@<host> aaru/infra/scripts/set-backup-credentials.sh --bucket ${aws_s3_bucket.backup.id} --kms-key-arn ${aws_kms_key.backup.arn} --region ${var.region}"
}
