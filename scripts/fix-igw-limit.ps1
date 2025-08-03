# Quick fix for IGW limit exceeded
$region = "ap-south-1"

Write-Host "🔍 Checking Internet Gateways in $region..." -ForegroundColor Yellow

# List all IGWs with region
Write-Host "Current Internet Gateways:" -ForegroundColor Green
aws ec2 describe-internet-gateways --region $region --query 'InternetGateways[*].[InternetGatewayId,State,Tags[?Key==`Name`].Value|[0]]' --output table

Write-Host ""
Write-Host "🔍 Checking VPC attachments..." -ForegroundColor Yellow
aws ec2 describe-internet-gateways --region $region --query 'InternetGateways[*].[InternetGatewayId,Attachments[0].VpcId,Attachments[0].State]' --output table

# Get current count
$igwCount = aws ec2 describe-internet-gateways --region $region --query 'length(InternetGateways)' --output text
Write-Host ""
Write-Host "Current IGW count: $igwCount/5" -ForegroundColor $(if ([int]$igwCount -ge 5) { "Red" } else { "Green" })

if ([int]$igwCount -ge 5) {
    Write-Host ""
    Write-Host "⚠️  You have reached the IGW limit!" -ForegroundColor Red
    Write-Host "Options to fix:" -ForegroundColor Yellow
    Write-Host "1. Delete unused VPCs (recommended)" -ForegroundColor White
    Write-Host "2. Use existing VPC for new deployment" -ForegroundColor White
    Write-Host "3. Request AWS limit increase" -ForegroundColor White
    
    Write-Host ""
    Write-Host "🔍 Checking for unused VPCs..." -ForegroundColor Yellow
    
    # List VPCs with instance counts
    aws ec2 describe-vpcs --region $region --query 'Vpcs[*].[VpcId,Tags[?Key==`Name`].Value|[0],IsDefault]' --output table
    
    Write-Host ""
    Write-Host "To delete a VPC and its IGW:" -ForegroundColor Cyan
    Write-Host "   aws ec2 delete-vpc --region $region --vpc-id vpc-xxxxxxxxx" -ForegroundColor White
    Write-Host "   (This will automatically delete the associated IGW)" -ForegroundColor White
}
}