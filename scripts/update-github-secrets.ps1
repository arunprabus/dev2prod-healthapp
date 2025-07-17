# Update GitHub Secrets PowerShell Script
# This script allows updating various GitHub secrets from different sources
# Usage: .\update-github-secrets.ps1 -Action <action> [options]

param(
    [Parameter(Mandatory=$false)]
    [string]$Action = "help",
    
    [Parameter(Mandatory=$false)]
    [string]$SecretName,
    
    [Parameter(Mandatory=$false)]
    [string]$SecretValue,
    
    [Parameter(Mandatory=$false)]
    [string]$FilePath,
    
    [Parameter(Mandatory=$false)]
    [string]$GitHubToken = $env:GITHUB_TOKEN,
    
    [Parameter(Mandatory=$false)]
    [string]$RepoName = $env:REPO_NAME
)

# If RepoName is not provided, try to get it from git
if (-not $RepoName) {
    try {
        $gitRemote = git config --get remote.origin.url
        if ($gitRemote -match "github.com[:/]([^/]+/[^/.]+)") {
            $RepoName = $Matches[1]
        }
    } catch {
        # Git command failed, continue with empty RepoName
    }
}

# Display help
function Show-Help {
    Write-Host "GitHub Secrets Management Script" -ForegroundColor Cyan
    Write-Host "Usage:" -ForegroundColor Yellow
    Write-Host "  .\update-github-secrets.ps1 -Action <action> [options]"
    Write-Host ""
    Write-Host "Actions:" -ForegroundColor Yellow
    Write-Host "  list                     - List all secrets in the repository"
    Write-Host "  update                   - Update a secret with a direct value"
    Write-Host "  update-file              - Update a secret from a file"
    Write-Host "  update-kubeconfig        - Update kubeconfig secret for an environment"
    Write-Host "  update-ssh-key           - Update SSH_PUBLIC_KEY and SSH_PRIVATE_KEY"
    Write-Host "  update-aws-creds         - Update AWS credentials from environment variables"
    Write-Host "  help                     - Show this help message"
    Write-Host ""
    Write-Host "Options:" -ForegroundColor Yellow
    Write-Host "  -SecretName <name>       - Name of the secret to update"
    Write-Host "  -SecretValue <value>     - Value for the secret (for update action)"
    Write-Host "  -FilePath <path>         - Path to file (for update-file and update-kubeconfig)"
    Write-Host "  -GitHubToken <token>     - GitHub token (or set GITHUB_TOKEN env var)"
    Write-Host "  -RepoName <owner/repo>   - Repository name (or set REPO_NAME env var)"
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor Yellow
    Write-Host "  .\update-github-secrets.ps1 -Action list"
    Write-Host "  .\update-github-secrets.ps1 -Action update -SecretName MY_SECRET -SecretValue 'secret-value'"
    Write-Host "  .\update-github-secrets.ps1 -Action update-file -SecretName API_KEY -FilePath api-key.txt"
    Write-Host "  .\update-github-secrets.ps1 -Action update-kubeconfig -SecretName dev -FilePath kubeconfig-lower.yaml"
    Write-Host ""
    Write-Host "Notes:" -ForegroundColor Yellow
    Write-Host "  - Set GITHUB_TOKEN environment variable or pass it with -GitHubToken"
    Write-Host "  - RepoName defaults to current git repository or can be set with -RepoName"
}

# Check GitHub token
function Test-GitHubToken {
    if (-not $GitHubToken) {
        Write-Host "❌ Error: GitHub token required" -ForegroundColor Red
        Write-Host "Set GITHUB_TOKEN environment variable or pass it with -GitHubToken"
        return $false
    }
    
    if (-not $RepoName) {
        Write-Host "❌ Error: Repository name required" -ForegroundColor Red
        Write-Host "Set REPO_NAME environment variable or pass it with -RepoName"
        return $false
    }
    
    return $true
}

# Get repository public key
function Get-RepoPublicKey {
    Write-Host "🔑 Getting repository public key..." -ForegroundColor Yellow
    
    $headers = @{
        "Authorization" = "token $GitHubToken"
        "Accept" = "application/vnd.github.v3+json"
    }
    
    try {
        $response = Invoke-RestMethod -Uri "https://api.github.com/repos/$RepoName/actions/secrets/public-key" -Headers $headers
        $script:PublicKey = $response.key
        $script:KeyId = $response.key_id
        
        Write-Host "✅ Got public key (ID: $KeyId)" -ForegroundColor Green
        return $true
    } catch {
        Write-Host "❌ Failed to get repository public key" -ForegroundColor Red
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Create or update a secret
function Set-GitHubSecret {
    param(
        [string]$Name,
        [string]$Value
    )
    
    Write-Host "🔐 Creating secret: $Name" -ForegroundColor Yellow
    
    # For PowerShell, we'll use a simplified approach
    # In production, you should use proper encryption with libsodium
    
    $headers = @{
        "Authorization" = "token $GitHubToken"
        "Accept" = "application/vnd.github.v3+json"
    }
    
    $body = @{
        encrypted_value = $Value
        key_id = $KeyId
    } | ConvertTo-Json
    
    try {
        $response = Invoke-RestMethod -Uri "https://api.github.com/repos/$RepoName/actions/secrets/$Name" -Method PUT -Headers $headers -Body $body -ContentType "application/json"
        Write-Host "✅ Created $Name" -ForegroundColor Green
        return $true
    } catch {
        Write-Host "❌ Failed to create $Name" -ForegroundColor Red
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# List all secrets
function Get-GitHubSecrets {
    if (-not (Test-GitHubToken)) { return }
    
    Write-Host "📋 Listing secrets for $RepoName..." -ForegroundColor Yellow
    
    $headers = @{
        "Authorization" = "token $GitHubToken"
        "Accept" = "application/vnd.github.v3+json"
    }
    
    try {
        $response = Invoke-RestMethod -Uri "https://api.github.com/repos/$RepoName/actions/secrets" -Headers $headers
        
        Write-Host "✅ Found $($response.total_count) secrets:" -ForegroundColor Green
        foreach ($secret in $response.secrets) {
            Write-Host "  - $($secret.name) (Updated: $($secret.updated_at))"
        }
    } catch {
        Write-Host "❌ Failed to list secrets" -ForegroundColor Red
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Update a secret with a direct value
function Update-GitHubSecret {
    if (-not (Test-GitHubToken)) { return }
    
    if (-not $SecretName) {
        Write-Host "❌ Error: Secret name required" -ForegroundColor Red
        Write-Host "Usage: .\update-github-secrets.ps1 -Action update -SecretName <name> -SecretValue <value>"
        return
    }
    
    if (-not $SecretValue) {
        Write-Host "❌ Error: Secret value required" -ForegroundColor Red
        Write-Host "Usage: .\update-github-secrets.ps1 -Action update -SecretName <name> -SecretValue <value>"
        return
    }
    
    if (-not (Get-RepoPublicKey)) { return }
    Set-GitHubSecret -Name $SecretName -Value $SecretValue
}

# Update a secret from a file
function Update-GitHubSecretFromFile {
    if (-not (Test-GitHubToken)) { return }
    
    if (-not $SecretName) {
        Write-Host "❌ Error: Secret name required" -ForegroundColor Red
        Write-Host "Usage: .\update-github-secrets.ps1 -Action update-file -SecretName <name> -FilePath <file>"
        return
    }
    
    if (-not $FilePath) {
        Write-Host "❌ Error: File path required" -ForegroundColor Red
        Write-Host "Usage: .\update-github-secrets.ps1 -Action update-file -SecretName <name> -FilePath <file>"
        return
    }
    
    if (-not (Test-Path $FilePath)) {
        Write-Host "❌ Error: File not found: $FilePath" -ForegroundColor Red
        return
    }
    
    $fileContent = Get-Content -Path $FilePath -Raw
    
    if (-not (Get-RepoPublicKey)) { return }
    Set-GitHubSecret -Name $SecretName -Value $fileContent
}

# Update kubeconfig secret for an environment
function Update-KubeconfigSecret {
    if (-not (Test-GitHubToken)) { return }
    
    $env = $SecretName
    $kubeconfigFile = $FilePath
    
    if (-not $env) {
        Write-Host "❌ Error: Environment required" -ForegroundColor Red
        Write-Host "Usage: .\update-github-secrets.ps1 -Action update-kubeconfig -SecretName <env> -FilePath <file>"
        return
    }
    
    if (-not $kubeconfigFile) {
        Write-Host "❌ Error: Kubeconfig file required" -ForegroundColor Red
        Write-Host "Usage: .\update-github-secrets.ps1 -Action update-kubeconfig -SecretName <env> -FilePath <file>"
        return
    }
    
    if (-not (Test-Path $kubeconfigFile)) {
        Write-Host "❌ Error: Kubeconfig file not found: $kubeconfigFile" -ForegroundColor Red
        return
    }
    
    # Create base64 encoded kubeconfig
    $kubeconfigContent = Get-Content -Path $kubeconfigFile -Raw
    $kubeconfigBytes = [System.Text.Encoding]::UTF8.GetBytes($kubeconfigContent)
    $kubeconfigB64 = [System.Convert]::ToBase64String($kubeconfigBytes)
    
    Write-Host "📦 Base64 kubeconfig created ($($kubeconfigB64.Length) characters)" -ForegroundColor Green
    
    if (-not (Get-RepoPublicKey)) { return }
    
    # Create the secret
    $secretName = "KUBECONFIG_$($env.ToUpper())"
    Set-GitHubSecret -Name $secretName -Value $kubeconfigB64
    
    # Extract server from kubeconfig
    $serverLine = Get-Content $kubeconfigFile | Where-Object { $_ -match "server:" }
    if ($serverLine) {
        $server = ($serverLine -split "server:")[1].Trim()
        Write-Host "ℹ️ Kubeconfig points to: $server" -ForegroundColor Blue
    }
}

# Update SSH keys
function Update-SSHKeys {
    if (-not (Test-GitHubToken)) { return }
    
    $sshKeyFile = if ($FilePath) { $FilePath } else { "$env:USERPROFILE\.ssh\k3s-key" }
    
    if (-not (Test-Path $sshKeyFile)) {
        Write-Host "❌ Error: SSH key file not found: $sshKeyFile" -ForegroundColor Red
        Write-Host "Generate SSH key with: ssh-keygen -t rsa -b 4096 -f $env:USERPROFILE\.ssh\k3s-key -N '' -C 'k3s-cluster-access'"
        return
    }
    
    if (-not (Test-Path "$sshKeyFile.pub")) {
        Write-Host "❌ Error: SSH public key file not found: $sshKeyFile.pub" -ForegroundColor Red
        return
    }
    
    # Read key files
    $privateKey = Get-Content -Path $sshKeyFile -Raw
    $publicKey = Get-Content -Path "$sshKeyFile.pub" -Raw
    
    if (-not (Get-RepoPublicKey)) { return }
    
    # Create the secrets
    Set-GitHubSecret -Name "SSH_PRIVATE_KEY" -Value $privateKey
    Set-GitHubSecret -Name "SSH_PUBLIC_KEY" -Value $publicKey
}

# Update AWS credentials
function Update-AWSCredentials {
    if (-not (Test-GitHubToken)) { return }
    
    $awsAccessKey = $env:AWS_ACCESS_KEY_ID
    $awsSecretKey = $env:AWS_SECRET_ACCESS_KEY
    
    if (-not $awsAccessKey) {
        Write-Host "❌ Error: AWS_ACCESS_KEY_ID environment variable not set" -ForegroundColor Red
        return
    }
    
    if (-not $awsSecretKey) {
        Write-Host "❌ Error: AWS_SECRET_ACCESS_KEY environment variable not set" -ForegroundColor Red
        return
    }
    
    if (-not (Get-RepoPublicKey)) { return }
    
    # Create the secrets
    Set-GitHubSecret -Name "AWS_ACCESS_KEY_ID" -Value $awsAccessKey
    Set-GitHubSecret -Name "AWS_SECRET_ACCESS_KEY" -Value $awsSecretKey
}

# Main execution
switch ($Action) {
    "list" { Get-GitHubSecrets }
    "update" { Update-GitHubSecret }
    "update-file" { Update-GitHubSecretFromFile }
    "update-kubeconfig" { Update-KubeconfigSecret }
    "update-ssh-key" { Update-SSHKeys }
    "update-aws-creds" { Update-AWSCredentials }
    default { Show-Help }
}