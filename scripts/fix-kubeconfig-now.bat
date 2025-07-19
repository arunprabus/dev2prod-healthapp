@echo off
echo 🔧 Quick Kubeconfig Fix
echo.

REM Check if kubeconfig file exists
if not exist "kubeconfig-lower.yaml" (
    echo ❌ kubeconfig-lower.yaml not found
    echo Please ensure the file exists in the current directory
    pause
    exit /b 1
)

echo ✅ Found kubeconfig-lower.yaml
echo.

REM Create base64 encoded version
echo 📦 Creating base64 encoded version...
certutil -encode kubeconfig-lower.yaml kubeconfig-base64.txt >nul 2>&1
if errorlevel 1 (
    echo ❌ Failed to encode kubeconfig
    pause
    exit /b 1
)

REM Remove header and footer from certutil output and create clean base64
powershell -Command "(Get-Content kubeconfig-base64.txt | Select-Object -Skip 1 | Select-Object -SkipLast 1) -join '' | Out-File -FilePath kubeconfig-clean-base64.txt -Encoding ascii -NoNewline"

echo ✅ Base64 encoding complete
echo.

echo 📋 COPY THIS VALUE FOR GITHUB SECRETS:
echo.
echo Secret Names: KUBECONFIG_DEV and KUBECONFIG_TEST
echo Secret Value:
type kubeconfig-clean-base64.txt
echo.
echo.

echo 📝 Instructions:
echo 1. Copy the base64 value above
echo 2. Go to GitHub → Settings → Secrets and variables → Actions
echo 3. Create/update these secrets with the copied value:
echo    - KUBECONFIG_DEV
echo    - KUBECONFIG_TEST
echo 4. Test with: Actions → Kubeconfig Access
echo.

REM Cleanup
del kubeconfig-base64.txt >nul 2>&1
del kubeconfig-clean-base64.txt >nul 2>&1

echo 🎉 Ready to update GitHub secrets!
pause