@echo off
echo 🔍 Checking VPC usage and identifying safe deletions...

echo.
echo Current VPCs:
aws ec2 describe-vpcs --query "Vpcs[?IsDefault==`false`].[VpcId,Tags[?Key==`Name`].Value|[0],State,CidrBlock]" --output table

echo.
echo VPC Count:
aws ec2 describe-vpcs --query "length(Vpcs[?IsDefault==`false`])" --output text

echo.
echo 🎯 Safe VPCs to delete (empty ones):
for /f "tokens=*" %%i in ('aws ec2 describe-vpcs --query "Vpcs[?IsDefault==`false`].VpcId" --output text') do (
    echo Checking VPC: %%i
    aws ec2 describe-instances --filters "Name=vpc-id,Values=%%i" --query "length(Reservations[].Instances[])" --output text > temp_count.txt
    set /p instance_count=<temp_count.txt
    if "!instance_count!"=="0" (
        echo   ✅ SAFE TO DELETE: %%i
        echo   Command: aws ec2 delete-vpc --vpc-id %%i
    ) else (
        echo   ⚠️  KEEP: %%i - has resources
    )
    echo.
)
del temp_count.txt 2>nul

echo.
echo 🗑️ To delete empty VPCs, run the commands shown above.