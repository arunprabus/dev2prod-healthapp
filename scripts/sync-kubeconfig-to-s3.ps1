# PowerShell script to sync kubeconfig files to S3
param(
    [string]$Environment = "lower",
    [string]$S3Bucket = "health-app-terraform-state"
)

Write-Host "🔧 Syncing kubeconfig to S3 for environment: $Environment" -ForegroundColor Blue

# Get cluster IP from AWS
Write-Host "📡 Getting cluster IP from AWS..." -ForegroundColor Yellow

$tagFilter = switch ($Environment) {
    "lower" { "*lower*k3s*" }
    "higher" { "*higher*k3s*" }
    "monitoring" { "*monitoring*k3s*" }
    default { "*k3s*" }
}

$clusterIP = aws ec2 describe-instances --filters "Name=tag:Name,Values=$tagFilter" "Name=instance-state-name,Values=running" --query "Reservations[0].Instances[0].PublicIpAddress" --output text

if ($clusterIP -eq "None" -or [string]::IsNullOrEmpty($clusterIP)) {
    Write-Host "❌ No running K3s cluster found for environment: $Environment" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Found cluster IP: $clusterIP" -ForegroundColor Green

# Create temp directory
$tempDir = "$env:TEMP\kubeconfig-sync"
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

# Generate kubeconfig locally (assuming you have SSH access)
Write-Host "🔑 Generating kubeconfig..." -ForegroundColor Yellow

$kubeconfigContent = @"
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0t...
    server: https://$clusterIP:6443
  name: health-app-$Environment
contexts:
- context:
    cluster: health-app-$Environment
    user: health-app-$Environment
  name: health-app-$Environment
current-context: health-app-$Environment
kind: Config
preferences: {}
users:
- name: health-app-$Environment
  user:
    token: K10...
"@

# Save to temp file
$tempFile = "$tempDir\kubeconfig-$Environment.yaml"
$kubeconfigContent | Out-File -FilePath $tempFile -Encoding UTF8

# Upload to S3
Write-Host "☁️ Uploading to S3..." -ForegroundColor Yellow

$s3Path = "kubeconfig/$Environment-network.yaml"
aws s3 cp $tempFile "s3://$S3Bucket/$s3Path"

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Kubeconfig uploaded to S3: s3://$S3Bucket/$s3Path" -ForegroundColor Green
    
    # Create environment-specific copies
    switch ($Environment) {
        "lower" {
            aws s3 cp $tempFile "s3://$S3Bucket/kubeconfig/dev-network.yaml"
            aws s3 cp $tempFile "s3://$S3Bucket/kubeconfig/test-network.yaml"
            Write-Host "✅ Created dev and test copies" -ForegroundColor Green
        }
        "higher" {
            aws s3 cp $tempFile "s3://$S3Bucket/kubeconfig/prod-network.yaml"
            Write-Host "✅ Created prod copy" -ForegroundColor Green
        }
    }
} else {
    Write-Host "❌ Failed to upload kubeconfig to S3" -ForegroundColor Red
    exit 1
}

# Cleanup
Remove-Item -Path $tempDir -Recurse -Force

Write-Host "🎉 Kubeconfig sync completed successfully!" -ForegroundColor Green
Write-Host "📋 Next steps:" -ForegroundColor Cyan
Write-Host "  1. Run Core Deployment workflow" -ForegroundColor White
Write-Host "  2. Kubeconfig will be automatically downloaded from S3" -ForegroundColor White