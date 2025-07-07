#!/bin/bash

# Convert Kubeconfig to GitHub Secret
# Usage: ./kubeconfig-to-github-secret.sh <environment> <public-ip> [ssh-key-path]

set -e

ENVIRONMENT=${1:-dev}
PUBLIC_IP=${2}
SSH_KEY=${3:-~/.ssh/k3s-key}
REPO_OWNER=${GITHUB_REPOSITORY_OWNER:-$(git config --get remote.origin.url | sed 's/.*github.com[:/]\([^/]*\).*/\1/')}
REPO_NAME=${GITHUB_REPOSITORY##*/}

if [ -z "$PUBLIC_IP" ]; then
    echo "❌ Error: Public IP is required"
    echo "Usage: $0 <environment> <public-ip> [ssh-key-path]"
    exit 1
fi

if [ -z "$GITHUB_TOKEN" ]; then
    echo "❌ Error: GITHUB_TOKEN environment variable is required"
    echo "Set it with: export GITHUB_TOKEN=your_token_here"
    exit 1
fi

echo "🔧 Creating GitHub Secret for $ENVIRONMENT kubeconfig..."

# Download and prepare kubeconfig
./setup-kubeconfig.sh "$ENVIRONMENT" "$PUBLIC_IP" "$SSH_KEY"

# Convert to base64
KUBECONFIG_B64=$(base64 -w 0 "kubeconfig-$ENVIRONMENT.yaml" 2>/dev/null || base64 "kubeconfig-$ENVIRONMENT.yaml")

# Secret name based on environment
SECRET_NAME="KUBECONFIG_$(echo $ENVIRONMENT | tr '[:lower:]' '[:upper:]')"

echo "📤 Uploading to GitHub Secrets as $SECRET_NAME..."

# Create/update GitHub secret using GitHub CLI
if command -v gh &> /dev/null; then
    echo "$KUBECONFIG_B64" | gh secret set "$SECRET_NAME" --body -
    echo "✅ GitHub Secret created: $SECRET_NAME"
else
    echo "⚠️  GitHub CLI not found. Manual steps:"
    echo "1. Go to: https://github.com/$REPO_OWNER/$REPO_NAME/settings/secrets/actions"
    echo "2. Create secret: $SECRET_NAME"
    echo "3. Value (base64 kubeconfig):"
    echo "$KUBECONFIG_B64"
fi

# Cleanup local kubeconfig
rm -f "kubeconfig-$ENVIRONMENT.yaml"
echo "🧹 Cleaned up local kubeconfig file"