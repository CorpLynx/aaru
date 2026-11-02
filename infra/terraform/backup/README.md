# Backup stack

The encrypted off-host target for `infra/scripts/backup.sh` (spec §10):

| Resource | Purpose |
| --- | --- |
| S3 bucket | Versioned, Object Lock on every version, public access blocked, TLS only, SSE-KMS required |
| KMS key | Customer-managed, yearly rotation. The account can administer it but only the backup user can encrypt or decrypt |
| IAM user | Put, get and list on the bucket, and use of the key. No delete, no lock changes |

## Apply

```sh
cd infra/terraform/backup
cp backend.hcl.example backend.hcl            # state bucket from ../bootstrap
cp terraform.tfvars.example terraform.tfvars  # region and bucket prefix
terraform init -backend-config=backend.hcl
terraform apply
```

## Give the host its credentials

The access key is created outside Terraform so it never lands in state. From
a machine with admin AWS credentials:

```sh
terraform output -raw install_command   # prints the command below, filled in
aws iam create-access-key --user-name aaru-backup --output json \
  | ssh aaru@<host> aaru/infra/scripts/set-backup-credentials.sh \
      --bucket <bucket_name> --kms-key-arn <kms_key_arn> --region <region>
```

The script stores the key in the `aaru-backup-aws` Podman secret and writes
the bucket, key ARN and region to `~/.config/aaru/backup.env`. Then on the host:

```sh
systemctl --user start aaru-backup.service      # first run, now
journalctl --user -u aaru-backup.service -n 30
systemctl --user enable --now aaru-backup.timer # daily at 03:00 UTC
```

Rotate the key quarterly: create a second key, re-run the script, then
`aws iam delete-access-key --user-name aaru-backup --access-key-id <old>`.

## Retention

`backup.sh` writes each run to `daily/`, copies Sunday's run to `weekly/` and
the run on the 1st to `monthly/`. The lifecycle rules expire them after 31,
84 and 366 days, and move monthly copies to Glacier Instant Retrieval after 30.

Every version is locked for `object_lock_days` (30). The mode starts as
`GOVERNANCE` so a mistake in the first weeks can still be cleaned up; switch
to `COMPLIANCE` after the first restore drill, as the spec asks. Under
`COMPLIANCE` nobody, the root user included, can delete a locked version
early, and the bucket cannot be destroyed until every lock has run out.

## Restore drill

`infra/scripts/restore-drill.sh` proves a backup restores without touching live
data: it downloads the newest daily backup (or a key you name), checks its
SHA-256 against the value recorded at upload, loads the dump into a throwaway
PostgreSQL container with no network, imports the web app volume into a
throwaway volume, and compares row counts with the live databases. Run it
before onboarding members and then quarterly; `healthcheck.sh` alerts when
the last passing drill is more than 100 days old.

```sh
infra/scripts/restore-drill.sh
infra/scripts/restore-drill.sh monthly/aaru-backup-<timestamp>.tar.gz
```

## Restore

The backup user can read as well as write, so a restore uses the same
credentials. On the host (or a staging machine holding them):

```sh
aws s3 ls s3://<bucket>/daily/
aws s3 cp s3://<bucket>/daily/aaru-backup-<timestamp>.tar.gz .
aws s3api head-object --bucket <bucket> --key daily/aaru-backup-<timestamp>.tar.gz \
  --query Metadata.sha256 --output text   # compare with: sha256sum <file>
tar xzf aaru-backup-<timestamp>.tar.gz
gunzip -c postgres/pg_dumpall.sql.gz | podman exec -i postgres psql -U aaru
podman volume import openwebui-data openwebui/openwebui-data.tar
```

Run this against a staging PostgreSQL before onboarding members (spec §10),
and quarterly after that.
