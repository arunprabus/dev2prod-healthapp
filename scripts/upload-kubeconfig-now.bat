@echo off
echo 🚀 Quick kubeconfig upload to S3
echo.

set CLUSTER_IP=13.235.132.195
set S3_BUCKET=health-app-terraform-state

echo Creating kubeconfig for cluster: %CLUSTER_IP%
echo S3 Bucket: %S3_BUCKET%
echo.

REM Create temp directory
mkdir %TEMP%\kubeconfig-upload 2>nul

echo 📝 Creating kubeconfig template...

REM Create kubeconfig content using PowerShell
powershell -Command "
$kubeconfig = @'
apiVersion: v1
clusters:
- cluster:
    insecure-skip-tls-verify: true
    server: https://%CLUSTER_IP%:6443
  name: health-app-lower
contexts:
- context:
    cluster: health-app-lower
    user: health-app-lower
  name: health-app-lower
current-context: health-app-lower
kind: Config
preferences: {}
users:
- name: health-app-lower
  user:
    token: 'K10...'
'@
$kubeconfig | Out-File -FilePath '%TEMP%\kubeconfig-upload\lower-network.yaml' -Encoding UTF8
"

echo ✅ Kubeconfig template created

echo ☁️ Uploading to S3...

REM Upload main file
aws s3 cp %TEMP%\kubeconfig-upload\lower-network.yaml s3://%S3_BUCKET%/kubeconfig/lower-network.yaml

if %ERRORLEVEL% eq 0 (
    echo ✅ Main kubeconfig uploaded
    
    REM Create copies for dev and test
    aws s3 cp %TEMP%\kubeconfig-upload\lower-network.yaml s3://%S3_BUCKET%/kubeconfig/dev-network.yaml
    aws s3 cp %TEMP%\kubeconfig-upload\lower-network.yaml s3://%S3_BUCKET%/kubeconfig/test-network.yaml
    
    echo ✅ Dev and test copies created
    echo.
    echo 🎉 All kubeconfig files uploaded successfully!
    echo.
    echo 📋 Files created:
    echo   - s3://%S3_BUCKET%/kubeconfig/lower-network.yaml
    echo   - s3://%S3_BUCKET%/kubeconfig/dev-network.yaml  
    echo   - s3://%S3_BUCKET%/kubeconfig/test-network.yaml
    echo.
    echo 🚀 You can now run the Core Deployment workflow!
) else (
    echo ❌ Failed to upload to S3
    echo Check AWS credentials and S3 bucket access
)

REM Cleanup
rmdir /s /q %TEMP%\kubeconfig-upload 2>nul

echo.
pause