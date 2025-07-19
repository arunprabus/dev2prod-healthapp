@echo off
setlocal enabledelayedexpansion

echo ===================================
echo GitHub Secrets Management Utility
echo ===================================
echo.

if "%1"=="" goto :menu

goto :execute

:menu
echo Choose an action:
echo.
echo 1. List all secrets
echo 2. Update a secret
echo 3. Update a secret from file
echo 4. Update kubeconfig
echo 5. Update SSH keys
echo 6. Update AWS credentials
echo 7. Exit
echo.

set /p choice="Enter your choice (1-7): "

if "%choice%"=="1" (
    set action=list
    goto :execute
)
if "%choice%"=="2" (
    set action=update
    set /p secret_name="Enter secret name: "
    set /p secret_value="Enter secret value: "
    goto :execute
)
if "%choice%"=="3" (
    set action=update-file
    set /p secret_name="Enter secret name: "
    set /p file_path="Enter file path: "
    goto :execute
)
if "%choice%"=="4" (
    set action=update-kubeconfig
    set /p env="Enter environment (dev/test/prod/monitoring): "
    set /p file_path="Enter kubeconfig file path (default: kubeconfig-lower.yaml): "
    if "!file_path!"=="" set file_path=kubeconfig-lower.yaml
    goto :execute
)
if "%choice%"=="5" (
    set action=update-ssh-key
    goto :execute
)
if "%choice%"=="6" (
    set action=update-aws-creds
    goto :execute
)
if "%choice%"=="7" goto :eof

echo Invalid choice. Please try again.
goto :menu

:execute
echo.
echo Executing: %action%

if "%action%"=="list" (
    powershell -ExecutionPolicy Bypass -File scripts\update-github-secrets.ps1 -Action list
) else if "%action%"=="update" (
    powershell -ExecutionPolicy Bypass -File scripts\update-github-secrets.ps1 -Action update -SecretName "%secret_name%" -SecretValue "%secret_value%"
) else if "%action%"=="update-file" (
    powershell -ExecutionPolicy Bypass -File scripts\update-github-secrets.ps1 -Action update-file -SecretName "%secret_name%" -FilePath "%file_path%"
) else if "%action%"=="update-kubeconfig" (
    powershell -ExecutionPolicy Bypass -File scripts\update-github-secrets.ps1 -Action update-kubeconfig -SecretName "%env%" -FilePath "%file_path%"
) else if "%action%"=="update-ssh-key" (
    powershell -ExecutionPolicy Bypass -File scripts\update-github-secrets.ps1 -Action update-ssh-key
) else if "%action%"=="update-aws-creds" (
    powershell -ExecutionPolicy Bypass -File scripts\update-github-secrets.ps1 -Action update-aws-creds
)

echo.
echo Operation completed.
echo.

if "%1"=="" (
    pause
    goto :menu
)

endlocal