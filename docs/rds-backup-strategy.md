# RDS Backup & Cost Optimization Strategy

## Current Issue
- RDS permissions limited (cannot create snapshots directly)
- RDS instance `healthapidb` costing ~$13-15/month

## Solution Options

### Option 1: Use Automated Backups (Recommended)
```bash
# Check existing automated backups
aws rds describe-db-snapshots --db-instance-identifier healthapidb --snapshot-type automated

# Stop RDS (keeps automated backups for 7 days)
aws rds stop-db-instance --db-instance-identifier healthapidb
```

### Option 2: Request Admin to Create Manual Snapshot
Ask admin to run:
```bash
aws rds create-db-snapshot --db-instance-identifier healthapidb --db-snapshot-identifier healthapidb-backup-$(date +%Y%m%d)
```

### Option 3: Data Export via Application
```bash
# Export data using pg_dump (if you have DB access)
pg_dump -h your-rds-endpoint -U postgres -d healthapi > healthapi_backup.sql

# Upload to S3
aws s3 cp healthapi_backup.sql s3://health-app-terraform-state/db-backups/
```

## Restore with Terraform

### Using Snapshot:
```bash
cd infra
terraform apply -var="restore_from_snapshot=true" -var="snapshot_identifier=healthapidb-backup-20250102"
```

### Using Fresh DB:
```bash
terraform apply -var="restore_from_snapshot=false"
```

## Cost Savings
- **Stop RDS**: Save $13-15/month
- **Snapshot storage**: ~$0.095/GB/month (minimal cost)
- **Restore when needed**: Only pay when running

## Next Steps
1. Stop RDS instance (saves costs immediately)
2. Use automated backups for restore
3. Recreate via Terraform when needed