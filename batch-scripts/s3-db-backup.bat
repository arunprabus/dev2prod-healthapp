@echo off
echo Exporting RDS data to S3...

REM Export RDS snapshot to S3 (requires IAM role)
aws rds start-export-task ^
  --export-task-identifier healthapi-export-%date:~-4,4%%date:~-10,2%%date:~-7,2% ^
  --source-arn arn:aws:rds:ap-south-1:943199871063:snapshot:healthapidb-backup-20250102 ^
  --s3-bucket-name health-app-terraform-state ^
  --s3-prefix db-exports/ ^
  --iam-role-arn arn:aws:iam::943199871063:role/rds-s3-export-role ^
  --kms-key-id arn:aws:kms:ap-south-1:943199871063:key/2cef1328-5555-4bfe-9909-9b811fb35fb7

echo Export started. Check status with:
echo aws rds describe-export-tasks --export-task-identifier healthapi-export-%date:~-4,4%%date:~-10,2%%date:~-7,2%