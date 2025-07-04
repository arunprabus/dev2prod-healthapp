@echo off
echo Updating security group to allow K3s API access...

REM Get security group ID
for /f "tokens=*" %%i in ('aws ec2 describe-instances --filters "Name=ip-address,Values=43.205.211.129" --query "Reservations[0].Instances[0].SecurityGroups[0].GroupId" --output text') do set SG_ID=%%i

echo Security Group ID: %SG_ID%

REM Add rule for K3s API server
aws ec2 authorize-security-group-ingress ^
    --group-id %SG_ID% ^
    --protocol tcp ^
    --port 6443 ^
    --cidr 0.0.0.0/0

echo K3s API server port 6443 opened to 0.0.0.0/0
echo GitHub Actions should now be able to connect