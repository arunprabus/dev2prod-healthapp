@echo off
echo 🧪 Verifying Lower Infrastructure Deployment...

REM Check AWS CLI is configured
aws sts get-caller-identity >nul 2>&1
if %errorlevel% neq 0 (
    echo ❌ AWS CLI not configured
    exit /b 1
)

echo ✅ AWS CLI configured

REM Check running instances
echo.
echo 📋 Checking EC2 Instances...
aws ec2 describe-instances --filters "Name=tag:Environment,Values=lower" "Name=instance-state-name,Values=running" --query "Reservations[].Instances[].{Name:Tags[?Key=='Name'].Value|[0],IP:PublicIpAddress,State:State.Name}" --output table

REM Check database
echo.
echo 🗄️ Checking Database...
aws rds describe-db-instances --db-instance-identifier health-app-shared-db --query "DBInstances[0].{Status:DBInstanceStatus,Endpoint:Endpoint.Address}" --output table

REM Get cluster IPs for manual testing
echo.
echo 🎯 Getting Cluster IPs for manual testing...
for /f "tokens=*" %%i in ('aws ec2 describe-instances --filters "Name=tag:Name,Values=health-app-lower-dev" "Name=instance-state-name,Values=running" --query "Reservations[0].Instances[0].PublicIpAddress" --output text') do set DEV_IP=%%i
for /f "tokens=*" %%i in ('aws ec2 describe-instances --filters "Name=tag:Name,Values=health-app-lower-test" "Name=instance-state-name,Values=running" --query "Reservations[0].Instances[0].PublicIpAddress" --output text') do set TEST_IP=%%i

echo Dev Cluster IP:  %DEV_IP%
echo Test Cluster IP: %TEST_IP%

echo.
echo 🎉 Verification Complete!
echo.
echo Next Steps:
echo 1. SSH to clusters: ssh ubuntu@[IP]
echo 2. Check K3s: sudo k3s kubectl get nodes
echo 3. Generate kubeconfigs for GitHub Secrets
echo 4. Deploy applications using core-deployment.yml workflow

pause