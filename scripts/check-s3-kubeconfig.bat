@echo off
echo 🔍 Checking S3 bucket for kubeconfig files...
echo.

set S3_BUCKET=health-app-terraform-state

echo 📂 Listing all files in S3 bucket:
aws s3 ls s3://%S3_BUCKET%/ --recursive

echo.
echo 🔧 Checking kubeconfig directory:
aws s3 ls s3://%S3_BUCKET%/kubeconfig/ 2>nul

if %ERRORLEVEL% neq 0 (
    echo ⚠️  No kubeconfig directory found in S3
    echo.
    echo 💡 To create kubeconfig files, run:
    echo    Actions → Core Infrastructure → deploy → lower
    echo.
    echo 🔄 Or manually sync existing cluster:
    echo    powershell -ExecutionPolicy Bypass -File scripts\sync-kubeconfig-to-s3.ps1 -Environment lower
) else (
    echo ✅ Kubeconfig files found in S3
)

echo.
echo 🏗️ Infrastructure state files:
aws s3 ls s3://%S3_BUCKET%/ | findstr tfstate

pause