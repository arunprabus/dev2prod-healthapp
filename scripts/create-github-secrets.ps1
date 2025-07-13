# Create GitHub Secrets PowerShell Script
# Usage: .\create-github-secrets.ps1 -GitHubToken "your-token" [-RepoName "owner/repo"]

param(
    [Parameter(Mandatory=$true)]
    [string]$GitHubToken,
    
    [Parameter(Mandatory=$false)]
    [string]$RepoName = "arunprabus/dev2prod-healthapp"
)

Write-Host "🔧 Creating GitHub secrets for kubeconfig..." -ForegroundColor Cyan

# Check if kubeconfig file exists
if (-not (Test-Path "kubeconfig-lower.yaml")) {
    Write-Host "❌ kubeconfig-lower.yaml not found" -ForegroundColor Red
    Write-Host "Please ensure the file exists in the current directory" -ForegroundColor Red
    exit 1
}

# Create base64 encoded kubeconfig
$kubeconfigContent = Get-Content "kubeconfig-lower.yaml" -Raw
$kubeconfigBytes = [System.Text.Encoding]::UTF8.GetBytes($kubeconfigContent)
$kubeconfigB64 = [System.Convert]::ToBase64String($kubeconfigBytes)

Write-Host "📦 Base64 kubeconfig created ($($kubeconfigB64.Length) characters)" -ForegroundColor Green

# Get repository public key
Write-Host "🔑 Getting repository public key..." -ForegroundColor Yellow

$headers = @{
    "Authorization" = "token $GitHubToken"
    "Accept" = "application/vnd.github.v3+json"
}

try {
    $publicKeyResponse = Invoke-RestMethod -Uri "https://api.github.com/repos/$RepoName/actions/secrets/public-key" -Headers $headers
    $publicKey = $publicKeyResponse.key
    $keyId = $publicKeyResponse.key_id
    
    Write-Host "✅ Got public key (ID: $keyId)" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to get repository public key" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Function to create secret (simplified - using base64 directly)
function Create-Secret {
    param(
        [string]$SecretName,
        [string]$SecretValue
    )
    
    Write-Host "🔐 Creating secret: $SecretName" -ForegroundColor Yellow
    
    # For simplicity, we'll use the base64 value directly
    # In production, you should encrypt with the public key using libsodium
    $body = @{
        encrypted_value = $SecretValue
        key_id = $keyId
    } | ConvertTo-Json
    
    try {
        $response = Invoke-RestMethod -Uri "https://api.github.com/repos/$RepoName/actions/secrets/$SecretName" -Method PUT -Headers $headers -Body $body -ContentType "application/json"
        Write-Host "✅ Created $SecretName" -ForegroundColor Green
        return $true
    } catch {
        Write-Host "❌ Failed to create $SecretName" -ForegroundColor Red
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Create the secrets
Write-Host ""
Write-Host "🚀 Creating kubeconfig secrets..." -ForegroundColor Cyan

$devSuccess = Create-Secret -SecretName "KUBECONFIG_DEV" -SecretValue $kubeconfigB64
$testSuccess = Create-Secret -SecretName "KUBECONFIG_TEST" -SecretValue $kubeconfigB64

Write-Host ""
Write-Host "🎉 Secret creation completed!" -ForegroundColor Green
Write-Host ""
Write-Host "📋 Summary:" -ForegroundColor Cyan
Write-Host "  - Repository: $RepoName"
Write-Host "  - KUBECONFIG_DEV: $(if($devSuccess){'✅ Created'}else{'❌ Failed'})"
Write-Host "  - KUBECONFIG_TEST: $(if($testSuccess){'✅ Created'}else{'❌ Failed'})"

# Extract server from kubeconfig
$serverLine = Get-Content "kubeconfig-lower.yaml" | Where-Object { $_ -match "server:" }
if ($serverLine) {
    $server = ($serverLine -split "server:")[1].Trim()
    Write-Host "  - Kubeconfig points to: $server"
}

Write-Host ""
Write-Host "🧪 Test with: Actions → Kubeconfig Access → environment: dev → action: test-connection" -ForegroundColor Yellow