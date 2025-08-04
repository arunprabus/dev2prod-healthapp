@echo off
echo 🔧 Manual Kubeconfig Fix for K3s Cluster
echo ========================================

set K3S_IP=13.232.6.250
set ENVIRONMENT=dev
set GITHUB_REPO=arunprabus/dev2prod-healthapp

echo 📍 K3s Cluster IP: %K3S_IP%
echo 🏷️ Environment: %ENVIRONMENT%

echo.
echo ⏳ Step 1: Testing SSH connection to K3s cluster...
ssh -i ~/.ssh/k3s-key -o StrictHostKeyChecking=no -o ConnectTimeout=10 ubuntu@%K3S_IP% "echo 'SSH connection successful'"
if errorlevel 1 (
    echo ❌ SSH connection failed. Please check:
    echo    - SSH key exists at ~/.ssh/k3s-key
    echo    - Security group allows SSH from your IP
    echo    - K3s instance is running
    pause
    exit /b 1
)

echo.
echo ⏳ Step 2: Checking K3s service status...
ssh -i ~/.ssh/k3s-key -o StrictHostKeyChecking=no ubuntu@%K3S_IP% "sudo systemctl is-active k3s"
if errorlevel 1 (
    echo ⚠️ K3s service not active, attempting to start...
    ssh -i ~/.ssh/k3s-key -o StrictHostKeyChecking=no ubuntu@%K3S_IP% "sudo systemctl start k3s && sleep 10"
)

echo.
echo ⏳ Step 3: Downloading kubeconfig from K3s cluster...
scp -i ~/.ssh/k3s-key -o StrictHostKeyChecking=no ubuntu@%K3S_IP%:/etc/rancher/k3s/k3s.yaml kubeconfig-%ENVIRONMENT%.yaml
if errorlevel 1 (
    echo ❌ Failed to download kubeconfig. Checking if file exists...
    ssh -i ~/.ssh/k3s-key -o StrictHostKeyChecking=no ubuntu@%K3S_IP% "sudo ls -la /etc/rancher/k3s/"
    pause
    exit /b 1
)

echo.
echo 🔧 Step 4: Updating kubeconfig server IP...
powershell -Command "(Get-Content kubeconfig-%ENVIRONMENT%.yaml) -replace '127.0.0.1', '%K3S_IP%' | Set-Content kubeconfig-%ENVIRONMENT%.yaml"

echo.
echo ✅ Step 5: Testing kubeconfig connectivity...
set KUBECONFIG=kubeconfig-%ENVIRONMENT%.yaml
kubectl cluster-info --request-timeout=30s
if errorlevel 1 (
    echo ❌ Kubeconfig test failed. Checking K3s API server...
    ssh -i ~/.ssh/k3s-key -o StrictHostKeyChecking=no ubuntu@%K3S_IP% "sudo journalctl -u k3s --no-pager -n 20"
    pause
    exit /b 1
)

echo.
echo 📤 Step 6: Converting kubeconfig to base64 for GitHub secret...
powershell -Command "[Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes((Get-Content kubeconfig-%ENVIRONMENT%.yaml -Raw)))" > kubeconfig-base64.txt

echo.
echo 🔐 Step 7: GitHub Secret Setup Instructions
echo ==========================================
echo 1. Go to: https://github.com/%GITHUB_REPO%/settings/secrets/actions
echo 2. Click "New repository secret"
echo 3. Name: KUBECONFIG_DEV
echo 4. Value: Copy content from kubeconfig-base64.txt
echo.
echo 📋 Base64 content (copy this):
type kubeconfig-base64.txt

echo.
echo 🎉 Manual kubeconfig setup completed!
echo.
echo 📁 Files created:
echo    - kubeconfig-%ENVIRONMENT%.yaml (working kubeconfig)
echo    - kubeconfig-base64.txt (for GitHub secret)
echo.
echo 🚀 Next steps:
echo    1. Add KUBECONFIG_DEV secret to GitHub
echo    2. Run: Actions → Core Deployment → health-api
echo.
pause