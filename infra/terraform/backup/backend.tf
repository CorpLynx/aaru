# Remote state in the bootstrap stack's bucket; see ../README.md.
#
#   cp backend.hcl.example backend.hcl   # then set bucket + region
#   terraform init -backend-config=backend.hcl

terraform {
  backend "s3" {}
}
