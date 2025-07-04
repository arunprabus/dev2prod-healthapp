param(
    [Parameter(Mandatory=$true)]
    [string]$Environment,
    
    [Parameter(Mandatory=$true)]
    [string]$ClusterIP
)

Write-Host "🔧 Generating kubeconfig for $Environment environment" -ForegroundColor Green
Write-Host "🌐 Cluster IP: $ClusterIP" -ForegroundColor Cyan

# Test SSH connection
Write-Host "🔍 Testing SSH connection..." -ForegroundColor Yellow
$sshTest = ssh -i "$env:USERPROFILE\.ssh\aws-key" -o ConnectTimeout=10 -o StrictHostKeyChecking=no ubuntu@$ClusterIP "echo Connected" 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ SSH connection failed" -ForegroundColor Red
    Write-Host "💡 Ensure:" -ForegroundColor Yellow
    Write-Host "   1. SSH key exists: $env:USERPROFILE\.ssh\aws-key"
    Write-Host "   2. Cluster is running: $ClusterIP"
    Write-Host "   3. Security group allows SSH (port 22)"
    exit 1
}

# Get K3s token
Write-Host "🔑 Retrieving K3s token..." -ForegroundColor Yellow
$K3sToken = ssh -i "$env:USERPROFILE\.ssh\aws-key" -o StrictHostKeyChecking=no ubuntu@$ClusterIP "sudo cat /var/lib/rancher/k3s/server/node-token" 2>$null

if ([string]::IsNullOrEmpty($K3sToken)) {
    Write-Host "❌ Failed to get K3s token" -ForegroundColor Red
    Write-Host "💡 K3s may not be ready. Wait 2-3 minutes after deployment." -ForegroundColor Yellow
    exit 1
}

# Create .kube directory
$kubeDir = "$env:USERPROFILE\.kube"
if (!(Test-Path $kubeDir)) {
    New-Item -ItemType Directory -Path $kubeDir | Out-Null
}

# Generate kubeconfig
$kubeconfigContent = @"
apiVersion: v1
kind: Config
clusters:
- cluster:
    server: https://$ClusterIP:6443
    insecure-skip-tls-verify: true
  name: health-app-$Environment
contexts:
- context:
    cluster: health-app-$Environment
    user: health-app-$Environment
  name: health-app-$Environment
current-context: health-app-$Environment
users:
- name: health-app-$Environment
  user:
    token: $K3sToken
"@

$kubeconfigPath = "$kubeDir\config-$Environment"
$kubeconfigContent | Out-File -FilePath $kubeconfigPath -Encoding UTF8

# Generate base64
$secretName = "KUBECONFIG_$($Environment.ToUpper())"
$base64Content = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($kubeconfigContent))

Write-Host ""
Write-Host "✅ Kubeconfig generated successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "📋 Add to GitHub Secrets:" -ForegroundColor Cyan
Write-Host "   Name: $secretName" -ForegroundColor White
Write-Host "   Value: $base64Content" -ForegroundColor Gray
Write-Host ""
Write-Host "🧪 Test locally:" -ForegroundColor Cyan
Write-Host "   `$env:KUBECONFIG = '$kubeconfigPath'" -ForegroundColor White
Write-Host "   kubectl get nodes" -ForegroundColor White