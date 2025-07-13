#!/bin/bash

# Create GitHub Secrets Script
# Usage: ./create-github-secrets.sh <github-token> [repo-name]

set -e

GITHUB_TOKEN=${1:-$GITHUB_TOKEN}
REPO_NAME=${2:-"arunprabus/dev2prod-healthapp"}

if [ -z "$GITHUB_TOKEN" ]; then
    echo "❌ Error: GitHub token required"
    echo "Usage: $0 <github-token> [repo-name]"
    echo "Or set GITHUB_TOKEN environment variable"
    exit 1
fi

if [ ! -f "kubeconfig-lower.yaml" ]; then
    echo "❌ kubeconfig-lower.yaml not found"
    echo "Please ensure the file exists in the current directory"
    exit 1
fi

echo "🔧 Creating GitHub secrets for kubeconfig..."

# Create base64 encoded kubeconfig
KUBECONFIG_B64=$(base64 -w 0 kubeconfig-lower.yaml)

echo "📦 Base64 kubeconfig created ($(echo $KUBECONFIG_B64 | wc -c) characters)"

# Get repository public key
echo "🔑 Getting repository public key..."
PUBLIC_KEY_RESPONSE=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
    "https://api.github.com/repos/$REPO_NAME/actions/secrets/public-key")

PUBLIC_KEY=$(echo "$PUBLIC_KEY_RESPONSE" | jq -r '.key')
KEY_ID=$(echo "$PUBLIC_KEY_RESPONSE" | jq -r '.key_id')

if [ "$KEY_ID" = "null" ]; then
    echo "❌ Failed to get repository public key"
    echo "Response: $PUBLIC_KEY_RESPONSE"
    exit 1
fi

echo "✅ Got public key (ID: $KEY_ID)"

# Function to encrypt and create secret
create_secret() {
    local secret_name=$1
    local secret_value=$2
    
    echo "🔐 Creating secret: $secret_name"
    
    # Check if we have the required tools
    if ! command -v python3 &> /dev/null; then
        echo "❌ Python3 not found"
        return 1
    fi
    
    # Install PyNaCl if not available
    if ! python3 -c "import nacl" 2>/dev/null; then
        echo "📦 Installing PyNaCl..."
        pip3 install PyNaCl
    fi
    
    # Encrypt the secret
    ENCRYPTED=$(python3 -c "
import base64
import nacl.encoding, nacl.public
public_key = nacl.public.PublicKey(base64.b64decode('$PUBLIC_KEY'), nacl.encoding.RawEncoder())
sealed_box = nacl.public.SealedBox(public_key)
encrypted = sealed_box.encrypt(b'$secret_value')
print(base64.b64encode(encrypted).decode())
")
    
    if [ -z "$ENCRYPTED" ]; then
        echo "❌ Failed to encrypt secret"
        return 1
    fi
    
    # Create secret via GitHub API
    RESPONSE=$(curl -s -X PUT \
        -H "Authorization: token $GITHUB_TOKEN" \
        -H "Accept: application/vnd.github.v3+json" \
        "https://api.github.com/repos/$REPO_NAME/actions/secrets/$secret_name" \
        -d "{\"encrypted_value\":\"$ENCRYPTED\",\"key_id\":\"$KEY_ID\"}")
    
    if echo "$RESPONSE" | grep -q "error\|message"; then
        echo "❌ Failed to create $secret_name"
        echo "Response: $RESPONSE"
        return 1
    else
        echo "✅ Created $secret_name"
        return 0
    fi
}

# Create the secrets
echo ""
echo "🚀 Creating kubeconfig secrets..."

if create_secret "KUBECONFIG_DEV" "$KUBECONFIG_B64"; then
    echo "✅ KUBECONFIG_DEV created successfully"
else
    echo "❌ Failed to create KUBECONFIG_DEV"
fi

if create_secret "KUBECONFIG_TEST" "$KUBECONFIG_B64"; then
    echo "✅ KUBECONFIG_TEST created successfully"
else
    echo "❌ Failed to create KUBECONFIG_TEST"
fi

echo ""
echo "🎉 Secret creation completed!"
echo ""
echo "📋 Summary:"
echo "  - Repository: $REPO_NAME"
echo "  - Secrets created: KUBECONFIG_DEV, KUBECONFIG_TEST"
echo "  - Kubeconfig points to: $(grep 'server:' kubeconfig-lower.yaml | awk '{print $2}')"
echo ""
echo "🧪 Test with: Actions → Kubeconfig Access → environment: dev → action: test-connection"