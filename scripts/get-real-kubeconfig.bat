@echo off
echo 🔧 Getting real kubeconfig from cluster...

set CLUSTER_IP=13.235.132.195
set ENVIRONMENT=lower
set S3_BUCKET=health-app-terraform-state

echo Cluster IP: %CLUSTER_IP%
echo Environment: %ENVIRONMENT%
echo.

echo 📡 Connecting to cluster via SSH...
echo Note: Make sure you have SSH access configured

REM Create temp directory
mkdir %TEMP%\kubeconfig-real 2>nul

echo 🔑 Getting kubeconfig from cluster...
ssh -i ~/.ssh/aws-key -o StrictHostKeyChecking=no ubuntu@%CLUSTER_IP% "sudo cat /etc/rancher/k3s/k3s.yaml" > %TEMP%\kubeconfig-real\k3s-raw.yaml

if %ERRORLEVEL% neq 0 (
    echo ❌ Failed to get kubeconfig from cluster
    echo 💡 Make sure SSH key is configured and cluster is accessible
    pause
    exit /b 1
)

echo ✅ Retrieved kubeconfig from cluster

echo 🔧 Processing kubeconfig...
REM Replace 127.0.0.1 with actual cluster IP using PowerShell
powershell -Command "(Get-Content '%TEMP%\kubeconfig-real\k3s-raw.yaml') -replace '127.0.0.1:6443', '%CLUSTER_IP%:6443' -replace 'name: default', 'name: health-app-%ENVIRONMENT%' -replace 'cluster: default', 'cluster: health-app-%ENVIRONMENT%' -replace 'context: default', 'context: health-app-%ENVIRONMENT%' -replace 'current-context: default', 'current-context: health-app-%ENVIRONMENT%' | Set-Content '%TEMP%\kubeconfig-real\kubeconfig-%ENVIRONMENT%.yaml'"

echo ☁️ Uploading to S3...
aws s3 cp %TEMP%\kubeconfig-real\kubeconfig-%ENVIRONMENT%.yaml s3://%S3_BUCKET%/kubeconfig/%ENVIRONMENT%-network.yaml

if %ERRORLEVEL% eq 0 (
    echo ✅ Main kubeconfig uploaded successfully
    
    REM Create environment-specific copies
    if "%ENVIRONMENT%"=="lower" (
        aws s3 cp %TEMP%\kubeconfig-real\kubeconfig-%ENVIRONMENT%.yaml s3://%S3_BUCKET%/kubeconfig/dev-network.yaml
        aws s3 cp %TEMP%\kubeconfig-real\kubeconfig-%ENVIRONMENT%.yaml s3://%S3_BUCKET%/kubeconfig/test-network.yaml
        echo ✅ Created dev and test copies
    )
    
    if "%ENVIRONMENT%"=="higher" (
        aws s3 cp %TEMP%\kubeconfig-real\kubeconfig-%ENVIRONMENT%.yaml s3://%S3_BUCKET%/kubeconfig/prod-network.yaml
        echo ✅ Created prod copy
    )
    
    echo.
    echo 🎉 Real kubeconfig uploaded to S3 successfully!
    echo 📋 You can now run the Core Deployment workflow
) else (
    echo ❌ Failed to upload to S3
)

REM Cleanup
rmdir /s /q %TEMP%\kubeconfig-real 2>nul

echo.
echo 📝 Next steps:
echo 1. Run Actions → Core Deployment → Manual deployment
echo 2. Select your environment (dev/test/prod)
echo.
pause