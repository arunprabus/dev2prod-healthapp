param(
    [string]$K3sIP = "13.232.6.250",
    [string]$Environment = "dev",
    [string]$GitHubRepo = "arunprabus/dev2prod-healthapp"
)

Write-Host "🔧 Manual Kubeconfig Fix for K3s Cluster" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "📍 K3s Cluster IP: $K3sIP" -ForegroundColor Yellow
Write-Host "🏷️ Environment: $Environment" -ForegroundColor Yellow
Write-Host ""

# Step 1: Test SSH connection
Write-Host "⏳ Step 1: Testing SSH connection..." -ForegroundColor Blue
try {
    $sshTest = ssh -i ~/.ssh/k3s-key -o StrictHostKeyChecking=no -o ConnectTimeout=10 ubuntu@$K3sIP "echo 'SSH OK'"
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ SSH connection successful" -ForegroundColor Green
    } else {
        throw "SSH connection failed"
    }
} catch {
    Write-Host "❌ SSH connection failed. Check:" -ForegroundColor Red
    Write-Host "   - SSH key exists at ~/.ssh/k3s-key" -ForegroundColor Red
    Write-Host "   - Security group allows SSH from your IP" -ForegroundColor Red
    Write-Host "   - K3s instance is running" -ForegroundColor Red
    exit 1
}

# Step 2: Check K3s service
Write-Host "⏳ Step 2: Checking K3s service..." -ForegroundColor Blue
$k3sStatus = ssh -i ~/.ssh/k3s-key -o StrictHostKeyChecking=no ubuntu@$K3sIP "sudo systemctl is-active k3s"
if ($LASTEXITCODE -ne 0) {
    Write-Host "⚠️ K3s not active, starting service..." -ForegroundColor Yellow
    ssh -i ~/.ssh/k3s-key -o StrictHostKeyChecking=no ubuntu@$K3sIP "sudo systemctl start k3s && sleep 15"
    Start-Sleep 5
}

# Step 3: Download kubeconfig
Write-Host "⏳ Step 3: Downloading kubeconfig..." -ForegroundColor Blue
$kubeconfigFile = "kubeconfig-$Environment.yaml"
scp -i ~/.ssh/k3s-key -o StrictHostKeyChecking=no ubuntu@${K3sIP}:/etc/rancher/k3s/k3s.yaml $kubeconfigFile

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to download kubeconfig" -ForegroundColor Red
    ssh -i ~/.ssh/k3s-key -o StrictHostKeyChecking=no ubuntu@$K3sIP "sudo ls -la /etc/rancher/k3s/"
    exit 1
}

# Step 4: Update server IP
Write-Host "🔧 Step 4: Updating server IP..." -ForegroundColor Blue
(Get-Content $kubeconfigFile) -replace '127.0.0.1', $K3sIP | Set-Content $kubeconfigFile

# Step 5: Test kubeconfig
Write-Host "✅ Step 5: Testing kubeconfig..." -ForegroundColor Blue
$env:KUBECONFIG = $kubeconfigFile
kubectl cluster-info --request-timeout=30s

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Kubeconfig test failed" -ForegroundColor Red
    ssh -i ~/.ssh/k3s-key -o StrictHostKeyChecking=no ubuntu@$K3sIP "sudo journalctl -u k3s --no-pager -n 20"
    exit 1
}

# Step 6: Create base64 for GitHub secret
Write-Host "📤 Step 6: Creating GitHub secret content..." -ForegroundColor Blue
$kubeconfigContent = Get-Content $kubeconfigFile -Raw
$base64Content = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($kubeconfigContent))
$base64Content | Out-File "kubeconfig-base64.txt" -Encoding ASCII

# Step 7: Instructions
Write-Host ""
Write-Host "🔐 Step 7: GitHub Secret Setup" -ForegroundColor Cyan
Write-Host "==============================" -ForegroundColor Cyan
Write-Host "1. Go to: https://github.com/$GitHubRepo/settings/secrets/actions" -ForegroundColor White
Write-Host "2. Click 'New repository secret'" -ForegroundColor White
Write-Host "3. Name: KUBECONFIG_$($Environment.ToUpper())" -ForegroundColor Yellow
Write-Host "4. Value: Copy content from kubeconfig-base64.txt" -ForegroundColor White
Write-Host ""
Write-Host "📋 Base64 content (copy this):" -ForegroundColor Green
Get-Content "kubeconfig-base64.txt"

Write-Host ""
Write-Host "🎉 Manual kubeconfig setup completed!" -ForegroundColor Green
Write-Host ""
Write-Host "📁 Files created:" -ForegroundColor Cyan
Write-Host "   - $kubeconfigFile (working kubeconfig)" -ForegroundColor White
Write-Host "   - kubeconfig-base64.txt (for GitHub secret)" -ForegroundColor White
Write-Host ""
Write-Host "🚀 Next steps:" -ForegroundColor Cyan
Write-Host "   1. Add KUBECONFIG_$($Environment.ToUpper()) secret to GitHub" -ForegroundColor White
Write-Host "   2. Run: Actions → Core Deployment → health-api" -ForegroundColor White