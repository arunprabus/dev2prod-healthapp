@echo off
echo Getting K3s token via AWS Systems Manager...

REM Get instance ID
for /f "tokens=*" %%i in ('aws ec2 describe-instances --filters "Name=ip-address,Values=43.205.211.129" --query "Reservations[0].Instances[0].InstanceId" --output text') do set INSTANCE_ID=%%i

echo Instance ID: %INSTANCE_ID%

REM Get token via Systems Manager
aws ssm send-command ^
    --instance-ids %INSTANCE_ID% ^
    --document-name "AWS-RunShellScript" ^
    --parameters "commands=['sudo cat /var/lib/rancher/k3s/server/node-token']" ^
    --query "Command.CommandId" --output text > temp_command_id.txt

set /p COMMAND_ID=<temp_command_id.txt
del temp_command_id.txt

echo Command ID: %COMMAND_ID%
echo Waiting for command to complete...
timeout /t 10 /nobreak >nul

REM Get command output
aws ssm get-command-invocation ^
    --command-id %COMMAND_ID% ^
    --instance-id %INSTANCE_ID% ^
    --query "StandardOutputContent" --output text

echo.
echo Copy the token above and add it as GitHub Secret: K3S_TOKEN