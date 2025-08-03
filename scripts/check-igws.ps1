$region = "ap-south-1"

Write-Host "Checking Internet Gateways in $region..."

# Get IGW count
$igwCount = aws ec2 describe-internet-gateways --region $region --query 'length(InternetGateways)' --output text
Write-Host "Current IGW count: $igwCount/5"

if ([int]$igwCount -ge 5) {
    Write-Host "IGW limit reached! Need to clean up unused VPCs."
    
    # List all VPCs
    Write-Host "Current VPCs:"
    aws ec2 describe-vpcs --region $region --query 'Vpcs[*].[VpcId,Tags[?Key==`Name`].Value|[0],IsDefault]' --output table
    
    Write-Host "To delete unused VPC: aws ec2 delete-vpc --region $region --vpc-id VPC_ID"
} else {
    Write-Host "IGW count is within limit."
}