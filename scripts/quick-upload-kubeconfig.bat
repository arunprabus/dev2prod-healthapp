@echo off
echo Creating kubeconfig for cluster IP: 13.235.132.195

set CLUSTER_IP=13.235.132.195
set S3_BUCKET=health-app-terraform-state

mkdir %TEMP%\kubeconfig 2>nul

echo apiVersion: v1 > %TEMP%\kubeconfig\config.yaml
echo clusters: >> %TEMP%\kubeconfig\config.yaml
echo - cluster: >> %TEMP%\kubeconfig\config.yaml
echo     insecure-skip-tls-verify: true >> %TEMP%\kubeconfig\config.yaml
echo     server: https://%CLUSTER_IP%:6443 >> %TEMP%\kubeconfig\config.yaml
echo   name: default >> %TEMP%\kubeconfig\config.yaml
echo contexts: >> %TEMP%\kubeconfig\config.yaml
echo - context: >> %TEMP%\kubeconfig\config.yaml
echo     cluster: default >> %TEMP%\kubeconfig\config.yaml
echo     user: default >> %TEMP%\kubeconfig\config.yaml
echo   name: default >> %TEMP%\kubeconfig\config.yaml
echo current-context: default >> %TEMP%\kubeconfig\config.yaml
echo kind: Config >> %TEMP%\kubeconfig\config.yaml
echo preferences: {} >> %TEMP%\kubeconfig\config.yaml
echo users: >> %TEMP%\kubeconfig\config.yaml
echo - name: default >> %TEMP%\kubeconfig\config.yaml
echo   user: >> %TEMP%\kubeconfig\config.yaml
echo     token: K10... >> %TEMP%\kubeconfig\config.yaml

aws s3 cp %TEMP%\kubeconfig\config.yaml s3://%S3_BUCKET%/kubeconfig/lower-network.yaml
aws s3 cp %TEMP%\kubeconfig\config.yaml s3://%S3_BUCKET%/kubeconfig/higher-network.yaml

rmdir /s /q %TEMP%\kubeconfig

echo Kubeconfig uploaded to S3
pause