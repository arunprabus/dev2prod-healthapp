@echo off
echo 🧹 Cleaning up existing resources that conflict...

REM Delete existing parameter group
aws rds delete-db-parameter-group --db-parameter-group-name health-app-shared-db-params 2>nul
if %errorlevel% equ 0 (
    echo ✅ Deleted parameter group
) else (
    echo ⚠️ Parameter group not found or already deleted
)

REM Delete existing KMS alias
aws kms delete-alias --alias-name alias/health-app-rds-export 2>nul
if %errorlevel% equ 0 (
    echo ✅ Deleted KMS alias
) else (
    echo ⚠️ KMS alias not found or already deleted
)

echo.
echo 🎉 Cleanup complete! Now retry the deployment.
echo.
echo Next steps:
echo 1. Go to GitHub Actions
echo 2. Re-run the Core Infrastructure workflow
echo 3. action: deploy, network: lower

pause