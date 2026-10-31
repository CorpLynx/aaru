# Remote state lives in S3. The bucket is created by the bootstrap stack in
# ../bootstrap, which runs with a local backend because a stack cannot create
# the bucket holding its own state.
#
#   cd ../bootstrap && terraform init && terraform apply
#   cp ../cloudflare/backend.hcl.example backend.hcl   # then set bucket + region
#   terraform init -migrate-state -force-copy -backend-config=backend.hcl
#
# backend.hcl is gitignored because it names the account's state bucket.
#
# use_lockfile gives the S3 backend its own locking mechanism (Terraform 1.10+),
# so no DynamoDB lock table is needed.

terraform {
  backend "s3" {}
}
