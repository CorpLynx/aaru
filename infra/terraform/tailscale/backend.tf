# Remote state in the bootstrap stack's bucket; see ../README.md. The auth keys
# this stack creates are in state, so the bucket's encryption and access
# controls apply to them.
#
#   cp backend.hcl.example backend.hcl   # then set bucket + region
#   terraform init -backend-config=backend.hcl

terraform {
  backend "s3" {}
}
