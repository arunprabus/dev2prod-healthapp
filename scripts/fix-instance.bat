@echo off
echo 🔧 Fixing instance reachability issue...
echo 🔄 Rebooting instance at 13.127.232.246

aws ec2 describe-instances --filters "Name=ip-address,Values=13.127.232.246" --query "Reservations[0].Instances[0].InstanceId" --output text > temp_instance_id.txt
set /p INSTANCE_ID=<temp_instance_id.txt
del temp_instance_id.txt

echo 📋 Instance ID: %INSTANCE_ID%
echo 🔄 Rebooting...

aws ec2 reboot-instances --instance-ids %INSTANCE_ID%

echo ✅ Reboot initiated
echo ⏱️ Wait 2-3 minutes, then check AWS console
echo 🔍 Instance should pass reachability checks