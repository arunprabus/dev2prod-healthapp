@echo off
setlocal enabledelayedexpansion

:: Update GitHub Secrets Batch Script
:: This script allows updating various GitHub secrets from different sources
:: Usage: update-github-secrets.bat <action> [options]

:: Default values
if "%GITHUB_TOKEN%"=="" set GITHUB_TOKEN=
if "%REPO_NAME%"=="" for /f "tokens=*" %%a in ('git config --get remote.origin.url ^| findstr /r "github.com"') do (
    set REPO_URL=%%a
    set REPO_URL=!REPO_URL:.git=!
    for /f "tokens=* delims=/" %%b in ("!REPO_URL!") do set REPO_NAME=%%~nxb
)

set ACTION=%1
set SECRET_NAME=%2
set SECRET_VALUE=%3
set SECRET_FILE=%4

:: Display help
if "%ACTION%"=="" goto :help
if "%ACTION%"=="help" goto :help

:: Check GitHub token
if "%GITHUB_TOKEN%"=="" (
    echo [31m❌ Error: GitHub token required[0m
    echo Set GITHUB_TOKEN environment variable or pass it as an argument
    exit /b 1
)

:: Process actions
if "%ACTION%"=="list" goto :list_secrets
if "%ACTION%"=="update" goto :update_secret
if "%ACTION%"=="update-file" goto :update_secret_from_file
if "%ACTION%"=="update-kubeconfig" goto :update_kubeconfig
if "%ACTION%"=="update-ssh-key" goto :update_ssh_keys
if "%ACTION%"=="update-aws-creds" goto :update_aws_creds
goto :help

:help
echo [34mGitHub Secrets Management Script[0m
echo [33mUsage:[0m
echo   %0 ^<action^> [options]
echo.
echo [33mActions:[0m
echo   list                     - List all secrets in the repository
echo   update ^<name^> ^<value^>    - Update a secret with a direct value
echo   update-file ^<name^> ^<file^>- Update a secret from a file
echo   update-kubeconfig ^<env^> ^<file^> - Update kubeconfig secret for an environment
echo   update-ssh-key           - Update SSH_PUBLIC_KEY and SSH_PRIVATE_KEY from ~/.ssh/k3s-key
echo   update-aws-creds         - Update AWS credentials from environment variables
echo   help                     - Show this help message
echo.
echo [33mExamples:[0m
echo   %0 update MY_SECRET "secret-value"
echo   %0 update-file API_KEY api-key.txt
echo   %0 update-kubeconfig dev kubeconfig-lower.yaml
echo   %0 update-kubeconfig prod kubeconfig-higher.yaml
echo.
echo [33mNotes:[0m
echo   - Set GITHUB_TOKEN environment variable or pass it as an argument
echo   - REPO_NAME defaults to current git repository or can be set as environment variable
exit /b 0

:list_secrets
echo [33m📋 Listing secrets for %REPO_NAME%...[0m
curl -s -H "Authorization: token %GITHUB_TOKEN%" ^
  -H "Accept: application/vnd.github.v3+json" ^
  "https://api.github.com/repos/%REPO_NAME%/actions/secrets" > secrets_response.json

type secrets_response.json | findstr "total_count" > nul
if %ERRORLEVEL% neq 0 (
    echo [31m❌ Failed to list secrets[0m
    type secrets_response.json
    del secrets_response.json
    exit /b 1
)

echo [32m✅ Found secrets:[0m
type secrets_response.json | findstr "name updated_at"
del secrets_response.json
exit /b 0

:update_secret
if "%SECRET_NAME%"=="" (
    echo [31m❌ Error: Secret name required[0m
    echo Usage: %0 update ^<name^> ^<value^>
    exit /b 1
)

if "%SECRET_VALUE%"=="" (
    echo [31m❌ Error: Secret value required[0m
    echo Usage: %0 update ^<name^> ^<value^>
    exit /b 1
)

call :get_public_key
if %ERRORLEVEL% neq 0 exit /b 1

call :create_secret "%SECRET_NAME%" "%SECRET_VALUE%"
exit /b %ERRORLEVEL%

:update_secret_from_file
if "%SECRET_NAME%"=="" (
    echo [31m❌ Error: Secret name required[0m
    echo Usage: %0 update-file ^<name^> ^<file^>
    exit /b 1
)

if "%SECRET_VALUE%"=="" (
    echo [31m❌ Error: File path required[0m
    echo Usage: %0 update-file ^<name^> ^<file^>
    exit /b 1
)

if not exist "%SECRET_VALUE%" (
    echo [31m❌ Error: File not found: %SECRET_VALUE%[0m
    exit /b 1
)

set /p FILE_CONTENT=<"%SECRET_VALUE%"

call :get_public_key
if %ERRORLEVEL% neq 0 exit /b 1

call :create_secret "%SECRET_NAME%" "%FILE_CONTENT%"
exit /b %ERRORLEVEL%

:update_kubeconfig
set ENV=%SECRET_NAME%
set KUBECONFIG_FILE=%SECRET_VALUE%

if "%ENV%"=="" (
    echo [31m❌ Error: Environment required[0m
    echo Usage: %0 update-kubeconfig ^<env^> ^<file^>
    exit /b 1
)

if "%KUBECONFIG_FILE%"=="" (
    echo [31m❌ Error: Kubeconfig file required[0m
    echo Usage: %0 update-kubeconfig ^<env^> ^<file^>
    exit /b 1
)

if not exist "%KUBECONFIG_FILE%" (
    echo [31m❌ Error: Kubeconfig file not found: %KUBECONFIG_FILE%[0m
    exit /b 1
)

echo [33m📦 Creating base64 encoded kubeconfig...[0m
certutil -encode "%KUBECONFIG_FILE%" kubeconfig_b64.tmp > nul
findstr /v /c:- kubeconfig_b64.tmp > kubeconfig_b64.txt
set /p KUBECONFIG_B64=<kubeconfig_b64.txt
del kubeconfig_b64.tmp kubeconfig_b64.txt

call :get_public_key
if %ERRORLEVEL% neq 0 exit /b 1

set SECRET_NAME=KUBECONFIG_%ENV%
call :create_secret "%SECRET_NAME%" "%KUBECONFIG_B64%"

echo [34mℹ️ Kubeconfig updated for environment: %ENV%[0m
exit /b 0

:update_ssh_keys
set SSH_KEY_FILE=%SECRET_NAME%
if "%SSH_KEY_FILE%"=="" set SSH_KEY_FILE=%USERPROFILE%\.ssh\k3s-key

if not exist "%SSH_KEY_FILE%" (
    echo [31m❌ Error: SSH key file not found: %SSH_KEY_FILE%[0m
    echo Generate SSH key with: ssh-keygen -t rsa -b 4096 -f %USERPROFILE%\.ssh\k3s-key -N "" -C "k3s-cluster-access"
    exit /b 1
)

if not exist "%SSH_KEY_FILE%.pub" (
    echo [31m❌ Error: SSH public key file not found: %SSH_KEY_FILE%.pub[0m
    exit /b 1
)

set /p PRIVATE_KEY=<"%SSH_KEY_FILE%"
set /p PUBLIC_KEY=<"%SSH_KEY_FILE%.pub"

call :get_public_key
if %ERRORLEVEL% neq 0 exit /b 1

call :create_secret "SSH_PRIVATE_KEY" "%PRIVATE_KEY%"
call :create_secret "SSH_PUBLIC_KEY" "%PUBLIC_KEY%"
exit /b 0

:update_aws_creds
if "%AWS_ACCESS_KEY_ID%"=="" (
    echo [31m❌ Error: AWS_ACCESS_KEY_ID environment variable not set[0m
    exit /b 1
)

if "%AWS_SECRET_ACCESS_KEY%"=="" (
    echo [31m❌ Error: AWS_SECRET_ACCESS_KEY environment variable not set[0m
    exit /b 1
)

call :get_public_key
if %ERRORLEVEL% neq 0 exit /b 1

call :create_secret "AWS_ACCESS_KEY_ID" "%AWS_ACCESS_KEY_ID%"
call :create_secret "AWS_SECRET_ACCESS_KEY" "%AWS_SECRET_ACCESS_KEY%"
exit /b 0

:get_public_key
echo [33m🔑 Getting repository public key...[0m
curl -s -H "Authorization: token %GITHUB_TOKEN%" ^
  "https://api.github.com/repos/%REPO_NAME%/actions/secrets/public-key" > public_key.json

type public_key.json | findstr "key_id" > nul
if %ERRORLEVEL% neq 0 (
    echo [31m❌ Failed to get repository public key[0m
    type public_key.json
    del public_key.json
    exit /b 1
)

for /f "tokens=2 delims=:, " %%a in ('type public_key.json ^| findstr "key"') do (
    set PUBLIC_KEY=%%a
    set PUBLIC_KEY=!PUBLIC_KEY:"=!
)

for /f "tokens=2 delims=:, " %%a in ('type public_key.json ^| findstr "key_id"') do (
    set KEY_ID=%%a
    set KEY_ID=!KEY_ID:"=!
)

echo [32m✅ Got public key (ID: %KEY_ID%)[0m
del public_key.json
exit /b 0

:create_secret
set SECRET_NAME=%~1
set SECRET_VALUE=%~2

echo [33m🔐 Creating secret: %SECRET_NAME%[0m

:: For Windows, we'll use a simplified approach with direct API call
:: In production, you should use proper encryption with libsodium

echo {"encrypted_value":"%SECRET_VALUE%","key_id":"%KEY_ID%"} > secret_payload.json

curl -s -X PUT ^
  -H "Authorization: token %GITHUB_TOKEN%" ^
  -H "Accept: application/vnd.github.v3+json" ^
  -H "Content-Type: application/json" ^
  "https://api.github.com/repos/%REPO_NAME%/actions/secrets/%SECRET_NAME%" ^
  -d @secret_payload.json > secret_response.json

type secret_response.json | findstr "error\|message" > nul
if %ERRORLEVEL% equ 0 (
    echo [31m❌ Failed to create %SECRET_NAME%[0m
    type secret_response.json
    del secret_payload.json secret_response.json
    exit /b 1
) else (
    echo [32m✅ Created %SECRET_NAME%[0m
    del secret_payload.json secret_response.json
    exit /b 0
)

endlocal