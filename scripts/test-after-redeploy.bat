@echo off
setlocal enabledelayedexpansion

REM Test Parameter Store and Kubeconfig after redeploy
REM Usage: test-after-redeploy.bat [environment]

set ENVIRONMENT=%1
if "%ENVIRONMENT%"=="" set ENVIRONMENT=dev
set REGION=ap-south-1

echo 🔄 Testing after redeploy for %ENVIRONMENT% environment
echo ==================================================

REM Step 1: Check if infrastructure is running
echo.
echo 🏗️ Step 1: Checking infrastructure status...

for /f "tokens=*" %%i in ('aws ec2 describe-instances --filters "Name=tag:Name,Values=health-app-lower-%ENVIRONMENT%" "Name=instance-state-name,Values=running" --query "Reservations[0].Instances[0].InstanceId" --output text 2^>nul') do set INSTANCE_ID=%%i
if "%INSTANCE_ID%"=="" set INSTANCE_ID=None

if not "%INSTANCE_ID%"=="None" (
    for /f "tokens=*" %%i in ('aws ec2 describe-instances --instance-ids %INSTANCE_ID% --query "Reservations[0].Instances[0].PublicIpAddress" --output text') do set PUBLIC_IP=%%i
    echo ✅ Infrastructure running: %INSTANCE_ID%
    echo 📡 Public IP: %PUBLIC_IP%
) else (
    echo ❌ No running infrastructure found
    echo Please wait for deployment to complete or check deployment status
    exit /b 1
)

REM Step 2: Check Parameter Store
echo.
echo 📋 Step 2: Checking Parameter Store parameters...

echo Available parameters:
aws ssm get-parameters-by-path --path "/%ENVIRONMENT%/health-app/" --region %REGION% --query "Parameters[*].[Name,Type]" --output table

REM Check specific parameters
for /f "tokens=*" %%i in ('aws ssm get-parameter --name "/%ENVIRONMENT%/health-app/kubeconfig/server" --region %REGION% --query "Parameter.Value" --output text 2^>nul') do set SERVER=%%i
if "%SERVER%"=="" set SERVER=NOT_FOUND

for /f "tokens=*" %%i in ('aws ssm get-parameter --name "/%ENVIRONMENT%/health-app/kubeconfig/token" --region %REGION% --query "Parameter.Name" --output text 2^>nul') do set TOKEN_EXISTS=%%i
if "%TOKEN_EXISTS%"=="" set TOKEN_EXISTS=NOT_FOUND

echo.
echo Kubeconfig parameters:
echo   Server: %SERVER%
if not "%TOKEN_EXISTS%"=="NOT_FOUND" (
    echo   Token: EXISTS
) else (
    echo   Token: MISSING
)

REM Step 3: Test kubeconfig if parameters exist
if not "%SERVER%"=="NOT_FOUND" if not "%TOKEN_EXISTS%"=="NOT_FOUND" (
    echo.
    echo 🔑 Step 3: Testing kubeconfig availability...
    echo ✅ Both server and token parameters found
    echo.
    echo To create and test kubeconfig:
    echo   bash ./scripts/get-kubeconfig-from-parameter-store.sh %ENVIRONMENT%
    echo.
    echo Or use the existing script:
    echo   bash ./scripts/test-after-redeploy.sh %ENVIRONMENT%
) else (
    echo.
    echo ⚠️  Step 3: Kubeconfig parameters missing
    echo   Run setup script after deployment completes:
    echo   bash ./scripts/setup-parameter-store-kubeconfig.sh %ENVIRONMENT%
)

echo.
echo 🎯 Summary for %ENVIRONMENT%:
echo ==========================
if not "%INSTANCE_ID%"=="None" (
    echo Infrastructure: ✅ Running
) else (
    echo Infrastructure: ❌ Missing
)

if not "%SERVER%"=="NOT_FOUND" (
    echo Server param:   ✅ Found
) else (
    echo Server param:   ❌ Missing
)

if not "%TOKEN_EXISTS%"=="NOT_FOUND" (
    echo Token param:    ✅ Found
) else (
    echo Token param:    ❌ Missing
)

echo.
echo Next steps:
echo 1. If parameters missing: bash ./scripts/setup-parameter-store-kubeconfig.sh %ENVIRONMENT%
echo 2. If connection fails: Wait for cluster to fully start (5-10 minutes)
echo 3. Get kubeconfig: bash ./scripts/get-kubeconfig-from-parameter-store.sh %ENVIRONMENT%