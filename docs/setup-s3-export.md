# S3 Export Setup - Admin Required

## Issue
Your user lacks IAM permissions to create roles. Need admin to run these commands:

## Admin Commands (One-time setup):

```bash
# 1. Create IAM role
aws iam create-role --role-name rds-s3-export-role --assume-role-policy-document '{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "export.rds.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}'

# 2. Attach S3 permissions
aws iam put-role-policy --role-name rds-s3-export-role --policy-name S3ExportPolicy --policy-document '{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject*",
        "s3:ListBucket",
        "s3:GetObject*"
      ],
      "Resource": [
        "arn:aws:s3:::health-app-terraform-state",
        "arn:aws:s3:::health-app-terraform-state/*"
      ]
    }
  ]
}'
```

## After Admin Setup - You Can Run:

```bash
aws rds start-export-task \
  --export-task-identifier healthapi-export-20250102 \
  --source-arn arn:aws:rds:ap-south-1:943199871063:snapshot:healthapidb-backup-20250102 \
  --s3-bucket-name health-app-terraform-state \
  --s3-prefix db-exports/ \
  --iam-role-arn arn:aws:iam::943199871063:role/rds-s3-export-role \
  --kms-key-id arn:aws:kms:ap-south-1:943199871063:key/2cef1328-5555-4bfe-9909-9b811fb35fb7
```

## Alternative: Manual Export (No Admin Required)

```bash
# Start RDS temporarily
aws rds start-db-instance --db-instance-identifier healthapidb

# Export via pg_dump (when RDS is running)
pg_dump -h healthapidb.ct4cmoguswkb.ap-south-1.rds.amazonaws.com -U postgres -d healthapi > healthapi_backup.sql

# Upload to S3
aws s3 cp healthapi_backup.sql s3://health-app-terraform-state/db-backups/

# Stop RDS again
aws rds stop-db-instance --db-instance-identifier healthapidb
```

**Cost Impact:**
- S3 storage: ~$0.05/month (vs $1.90 for snapshot)
- Savings: $1.85/month