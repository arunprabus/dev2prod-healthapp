@echo off
setlocal enabledelayedexpansion

set ENV=%1
set CLUSTER_IP=%2

if "%ENV%"=="" (
    echo Usage: %0 ^<env^> ^<cluster-ip^>
    exit /b 1
)

if "%CLUSTER_IP%"=="" (
    echo Usage: %0 ^<env^> ^<cluster-ip^>
    exit /b 1
)

echo Generating kubeconfig for %ENV% environment...
echo Cluster IP: %CLUSTER_IP%

REM Create temp file for kubeconfig
set TEMP_CONFIG=kubeconfig-%ENV%.yaml

REM SSH and get K3s config
ssh -i %USERPROFILE%\.ssh\aws-key -o StrictHostKeyChecking=no ubuntu@%CLUSTER_IP% "sudo cat /etc/rancher/k3s/k3s.yaml" > %TEMP_CONFIG%

if errorlevel 1 (
    echo Failed to retrieve kubeconfig
    exit /b 1
)

REM Replace 127.0.0.1 with actual cluster IP
powershell -Command "(Get-Content '%TEMP_CONFIG%') -replace '127.0.0.1:6443', '%CLUSTER_IP%:6443' | Set-Content '%TEMP_CONFIG%'"

REM Generate base64
powershell -Command "[Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes((Get-Content '%TEMP_CONFIG%' -Raw)))"

REM Cleanup
del %TEMP_CONFIG%