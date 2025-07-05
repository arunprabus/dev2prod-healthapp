# Manual kubeconfig sync to S3
param(
    [string]$ClusterIP = "13.235.132.195",
    [string]$Environment = "lower",
    [string]$S3Bucket = "health-app-terraform-state"
)

Write-Host "🔧 Manual kubeconfig sync to S3" -ForegroundColor Blue
Write-Host "Cluster IP: $ClusterIP" -ForegroundColor Yellow
Write-Host "Environment: $Environment" -ForegroundColor Yellow

# Create a basic kubeconfig template
$kubeconfigTemplate = @"
apiVersion: v1
clusters:
- cluster:
    insecure-skip-tls-verify: true
    server: https://$ClusterIP:6443
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
    token: "K10..."
"@

# Create temp directory
$tempDir = "$env:TEMP\kubeconfig-manual"
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

# Save kubeconfig template
$tempFile = "$tempDir\kubeconfig-$Environment.yaml"
$kubeconfigTemplate | Out-File -FilePath $tempFile -Encoding UTF8

Write-Host "📁 Created kubeconfig template: $tempFile" -ForegroundColor Green

# Upload to S3
Write-Host "☁️ Uploading to S3..." -ForegroundColor Yellow

$s3Path = "kubeconfig/$Environment-network.yaml"
aws s3 cp $tempFile "s3://$S3Bucket/$s3Path"

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Main kubeconfig uploaded: s3://$S3Bucket/$s3Path" -ForegroundColor Green
    
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
    
    Write-Host "🎉 Kubeconfig sync completed!" -ForegroundColor Green
    Write-Host "📋 Note: This is a template - you may need to get the actual token from the cluster" -ForegroundColor Yellow
} else {
    Write-Host "❌ Failed to upload to S3" -ForegroundColor Red
}

# Cleanup
Remove-Item -Path $tempDir -Recurse -Force

Write-Host "📝 Next steps:" -ForegroundColor Cyan
Write-Host "1. Run Core Deployment workflow" -ForegroundColor White
Write-Host "2. If authentication fails, get real token from cluster" -ForegroundColor White