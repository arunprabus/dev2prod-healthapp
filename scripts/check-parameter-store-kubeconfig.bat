@echo off
setlocal enabledelayedexpansion

REM Check Parameter Store Kubeconfig Status and Setup
REM Usage: check-parameter-store-kubeconfig.bat [environment]

set ENVIRONMENT=%1
if "%ENVIRONMENT%"=="" set ENVIRONMENT=all
set REGION=ap-south-1

echo 🔍 Checking Parameter Store Kubeconfig Status
echo ==============================================

if "%ENVIRONMENT%"=="all" (
    echo Checking all environments...
    call :check_environment dev
    call :check_environment test
    call :check_environment prod
) else (
    call :check_environment %ENVIRONMENT%
)

echo.
echo 🚀 Quick Actions:
echo ==================
echo 1. Setup Parameter Store for dev:  bash ./scripts/setup-parameter-store-kubeconfig.sh dev
echo 2. Get kubeconfig for dev:         bash ./scripts/get-kubeconfig-from-parameter-store.sh dev
echo 3. Test cluster connection:        bash ./scripts/test-lower-deployment.sh
echo 4. Check all parameters:           aws ssm get-parameters-by-path --path "/dev/health-app/" --region ap-south-1
echo.
echo 📚 Documentation: docs/PARAMETER-STORE-KUBECONFIG.md
goto :eof

:check_environment
set env=%1
echo.
echo 📋 Environment: %env%
echo -------------------

REM Check if parameters exist
echo 🔍 Checking Parameter Store parameters...

set server_param=/%env%/health-app/kubeconfig/server
set token_param=/%env%/health-app/kubeconfig/token
set cluster_param=/%env%/health-app/kubeconfig/cluster-name

REM Check server parameter
for /f "tokens=*" %%i in ('aws ssm get-parameter --name "%server_param%" --region %REGION% --query "Parameter.Value" --output text 2^>nul') do set SERVER=%%i
if "%SERVER%"=="" set SERVER=NOT_FOUND

REM Check token parameter
for /f "tokens=*" %%i in ('aws ssm get-parameter --name "%token_param%" --region %REGION% --query "Parameter.Name" --output text 2^>nul') do set TOKEN_EXISTS=%%i
if "%TOKEN_EXISTS%"=="" set TOKEN_EXISTS=NOT_FOUND

REM Check cluster name parameter
for /f "tokens=*" %%i in ('aws ssm get-parameter --name "%cluster_param%" --region %REGION% --query "Parameter.Value" --output text 2^>nul') do set CLUSTER_NAME=%%i
if "%CLUSTER_NAME%"=="" set CLUSTER_NAME=NOT_FOUND

REM Display results
if not "%SERVER%"=="NOT_FOUND" (
    echo ✅ Server: %SERVER%
) else (
    echo ❌ Server parameter not found: %server_param%
)

if not "%TOKEN_EXISTS%"=="NOT_FOUND" (
    echo ✅ Token: Parameter exists ^(encrypted^)
) else (
    echo ❌ Token parameter not found: %token_param%
)

if not "%CLUSTER_NAME%"=="NOT_FOUND" (
    echo ✅ Cluster Name: %CLUSTER_NAME%
) else (
    echo ❌ Cluster Name parameter not found: %cluster_param%
)

REM Check if infrastructure exists
echo.
echo 🏗️ Checking infrastructure status...
for /f "tokens=*" %%i in ('aws ec2 describe-instances --filters "Name=tag:Name,Values=health-app-lower-%env%" "Name=instance-state-name,Values=running" --query "Reservations[0].Instances[0].InstanceId" --output text 2^>nul') do set INSTANCE_ID=%%i
if "%INSTANCE_ID%"=="" set INSTANCE_ID=None

if not "%INSTANCE_ID%"=="None" (
    echo ✅ Infrastructure: Running ^(Instance: %INSTANCE_ID%^)
    
    REM Get public IP
    for /f "tokens=*" %%i in ('aws ec2 describe-instances --instance-ids %INSTANCE_ID% --query "Reservations[0].Instances[0].PublicIpAddress" --output text 2^>nul') do set PUBLIC_IP=%%i
    if "%PUBLIC_IP%"=="" set PUBLIC_IP=Unknown
    echo 📡 Public IP: %PUBLIC_IP%
    
    REM Check SSM agent status
    for /f "tokens=*" %%i in ('aws ssm describe-instance-information --filters "Key=InstanceIds,Values=%INSTANCE_ID%" --query "InstanceInformationList[0].PingStatus" --output text 2^>nul') do set SSM_STATUS=%%i
    if "%SSM_STATUS%"=="" set SSM_STATUS=Unknown
    echo 🔧 SSM Agent: %SSM_STATUS%
) else (
    echo ❌ Infrastructure: No running instances found
)

REM Overall status
echo.
if not "%SERVER%"=="NOT_FOUND" if not "%TOKEN_EXISTS%"=="NOT_FOUND" (
    echo 🎉 Status: READY - Kubeconfig available in Parameter Store
    echo 📝 To use: bash ./scripts/get-kubeconfig-from-parameter-store.sh %env%
) else if not "%INSTANCE_ID%"=="None" (
    echo ⚠️  Status: SETUP NEEDED - Infrastructure exists but kubeconfig not in Parameter Store
    echo 📝 To setup: bash ./scripts/setup-parameter-store-kubeconfig.sh %env%
) else (
    echo ❌ Status: INFRASTRUCTURE MISSING - Deploy infrastructure first
    echo 📝 To deploy: Run GitHub Actions workflow or terraform apply
)

goto :eof