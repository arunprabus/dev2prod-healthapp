@echo off
echo Creating RDS snapshot and backup strategy...

REM Create manual snapshot
aws rds create-db-snapshot --db-instance-identifier healthapidb --db-snapshot-identifier healthapidb-backup-%date:~-4,4%%date:~-10,2%%date:~-7,2%

REM Wait for snapshot completion
echo Waiting for snapshot to complete...
aws rds wait db-snapshot-completed --db-snapshot-identifier healthapidb-backup-%date:~-4,4%%date:~-10,2%%date:~-7,2%

REM Export snapshot to S3 (requires KMS key)
echo Exporting snapshot to S3...
aws rds start-export-task --export-task-identifier healthapi-export-%date:~-4,4%%date:~-10,2%%date:~-7,2% --source-arn arn:aws:rds:ap-south-1:943199871063:snapshot:healthapidb-backup-%date:~-4,4%%date:~-10,2%%date:~-7,2% --s3-bucket-name health-app-terraform-state --s3-prefix rds-backups/ --iam-role-arn arn:aws:iam::943199871063:role/rds-s3-export-role

REM Delete RDS instance after backup
echo Deleting RDS instance...
aws rds delete-db-instance --db-instance-identifier healthapidb --skip-final-snapshot --delete-automated-backups

echo Backup complete. RDS instance deleted. Monthly savings: ~$13-15