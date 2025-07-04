@echo off
setlocal enabledelayedexpansion

set ENVIRONMENT=%1
set CLUSTER_IP=%2

if "%ENVIRONMENT%"=="" (
    echo Usage: %0 ^<environment^> ^<cluster-ip^>
    echo Examples:
    echo   %0 lower 1.2.3.4
    echo   %0 higher 5.6.7.8
    echo   %0 monitoring 9.10.11.12
    exit /b 1
)

if "%CLUSTER_IP%"=="" (
    echo Usage: %0 ^<environment^> ^<cluster-ip^>
    echo Examples:
    echo   %0 lower 1.2.3.4
    echo   %0 higher 5.6.7.8
    echo   %0 monitoring 9.10.11.12
    exit /b 1
)

echo 🔧 Generating kubeconfig for %ENVIRONMENT% environment
echo 🌐 Cluster IP: %CLUSTER_IP%

echo.
echo 🔍 Testing SSH connection...
ssh -i %USERPROFILE%\.ssh\aws-key -o ConnectTimeout=10 -o StrictHostKeyChecking=no ubuntu@%CLUSTER_IP% "echo Connected" >nul 2>&1
if errorlevel 1 (
    echo ❌ SSH connection failed
    echo 💡 Ensure:
    echo    1. SSH key exists: %USERPROFILE%\.ssh\aws-key
    echo    2. Cluster is running: %CLUSTER_IP%
    echo    3. Security group allows SSH ^(port 22^)
    echo.
    echo 🔑 If you don't have the SSH key, create it:
    echo    ssh-keygen -t rsa -b 4096 -f %USERPROFILE%\.ssh\aws-key
    exit /b 1
)

echo 🔑 Retrieving K3s token...
for /f "delims=" %%i in ('ssh -i %USERPROFILE%\.ssh\aws-key -o StrictHostKeyChecking=no ubuntu@%CLUSTER_IP% "sudo cat /var/lib/rancher/k3s/server/node-token" 2^>nul') do set K3S_TOKEN=%%i

if "%K3S_TOKEN%"=="" (
    echo ❌ Failed to get K3s token
    echo 💡 K3s may not be ready. Wait 2-3 minutes after deployment.
    exit /b 1
)

echo 📝 Creating kubeconfig...
if not exist "%USERPROFILE%\.kube" mkdir "%USERPROFILE%\.kube"

(
echo apiVersion: v1
echo kind: Config
echo clusters:
echo - cluster:
echo     server: https://%CLUSTER_IP%:6443
echo     insecure-skip-tls-verify: true
echo   name: health-app-%ENVIRONMENT%
echo contexts:
echo - context:
echo     cluster: health-app-%ENVIRONMENT%
echo     user: health-app-%ENVIRONMENT%
echo   name: health-app-%ENVIRONMENT%
echo current-context: health-app-%ENVIRONMENT%
echo users:
echo - name: health-app-%ENVIRONMENT%
echo   user:
echo     token: %K3S_TOKEN%
) > "%USERPROFILE%\.kube\config-%ENVIRONMENT%"

echo 🔐 Generating base64 for GitHub Secrets...
set SECRET_NAME=KUBECONFIG_%ENVIRONMENT%
call :toupper SECRET_NAME

powershell -Command "[Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes((Get-Content '%USERPROFILE%\.kube\config-%ENVIRONMENT%' -Raw)))" > temp_base64.txt
set /p BASE64_CONFIG=<temp_base64.txt
del temp_base64.txt

echo.
echo ✅ Kubeconfig generated successfully!
echo.
echo 📋 Add to GitHub Secrets:
echo    Name: %SECRET_NAME%
echo    Value: %BASE64_CONFIG%
echo.
echo 🔗 Steps:
echo    1. Go to Settings → Secrets and variables → Actions
echo    2. Click 'New repository secret'
echo    3. Name: %SECRET_NAME%
echo    4. Secret: Copy the base64 value above
echo    5. Click 'Add secret'
echo.
echo 🧪 Test locally:
echo    set KUBECONFIG=%USERPROFILE%\.kube\config-%ENVIRONMENT%
echo    kubectl get nodes

goto :eof

:toupper
for %%i in (a b c d e f g h i j k l m n o p q r s t u v w x y z) do (
    call set %1=!%1:%%i=%%i!
)
for %%i in (A B C D E F G H I J K L M N O P Q R S T U V W X Y Z) do (
    call set %1=!%1:%%i=%%i!
)
goto :eof