Write-Host "🔍 Checking Internet Gateways..." -ForegroundColor Yellow

# List all IGWs
Write-Host "Current Internet Gateways:" -ForegroundColor Green
aws ec2 describe-internet-gateways --query 'InternetGateways[*].[InternetGatewayId,State,Tags[?Key==`Name`].Value|[0]]' --output table

Write-Host ""
Write-Host "🔍 Checking VPC attachments..." -ForegroundColor Yellow
aws ec2 describe-internet-gateways --query 'InternetGateways[*].[InternetGatewayId,Attachments[0].VpcId,Attachments[0].State]' --output table

Write-Host ""
Write-Host "🧹 Finding detached IGWs to clean up..." -ForegroundColor Yellow

# Get detached IGWs
$detachedIgws = aws ec2 describe-internet-gateways --query 'InternetGateways[?length(Attachments)==`0`].InternetGatewayId' --output text

if ($detachedIgws -and $detachedIgws.Trim() -ne "") {
    Write-Host "Found detached IGWs: $detachedIgws" -ForegroundColor Red
    Write-Host "Cleaning up detached IGWs..." -ForegroundColor Yellow
    
    $igwList = $detachedIgws.Split("`t")
    foreach ($igw in $igwList) {
        if ($igw.Trim() -ne "") {
            Write-Host "Deleting IGW: $igw" -ForegroundColor Red
            aws ec2 delete-internet-gateway --internet-gateway-id $igw.Trim()
        }
    }
} else {
    Write-Host "No detached IGWs found." -ForegroundColor Green
}

Write-Host ""
Write-Host "✅ Cleanup complete. Current IGW count:" -ForegroundColor Green
aws ec2 describe-internet-gateways --query 'length(InternetGateways)' --output text

Write-Host ""
Write-Host "💡 If you still have 5+ IGWs, you may need to:" -ForegroundColor Cyan
Write-Host "   1. Delete unused VPCs (which will delete their IGWs)" -ForegroundColor White
Write-Host "   2. Check for IGWs in other regions" -ForegroundColor White
Write-Host "   3. Contact AWS support to increase the limit" -ForegroundColor White