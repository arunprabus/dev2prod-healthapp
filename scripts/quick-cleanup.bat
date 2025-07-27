@echo off
echo 🧹 Quick cleanup of conflicting resources...

aws rds delete-db-parameter-group --db-parameter-group-name health-app-shared-db-params 2>nul
aws kms delete-alias --alias-name alias/health-app-rds-export 2>nul

echo ✅ Cleanup done! Re-run deployment now.