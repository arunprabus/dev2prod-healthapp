#!/bin/bash

# Generate SSH Key for K3s Clusters
# Usage: ./generate-ssh-key.sh [key-name]

set -e

KEY_NAME=${1:-k3s-key}
KEY_PATH="$HOME/.ssh/$KEY_NAME"

echo "🔑 Generating SSH key pair for K3s clusters..."

# Check if key already exists
if [ -f "$KEY_PATH" ]; then
    echo "⚠️  SSH key already exists at $KEY_PATH"
    read -p "Do you want to overwrite it? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "❌ Aborted. Using existing key."
        exit 0
    fi
fi

# Generate SSH key pair
ssh-keygen -t rsa -b 4096 -f "$KEY_PATH" -N "" -C "k3s-cluster-access"

# Set proper permissions
chmod 600 "$KEY_PATH"
chmod 644 "$KEY_PATH.pub"

echo "✅ SSH key pair generated successfully!"
echo ""
echo "🔑 Private key: $KEY_PATH"
echo "🔓 Public key:  $KEY_PATH.pub"
echo ""
echo "📋 Public key content (copy this for Terraform):"
echo "----------------------------------------"
cat "$KEY_PATH.pub"
echo "----------------------------------------"
echo ""
echo "🚀 Next steps:"
echo "1. Copy the public key content above"
echo "2. Set it as SSH_PUBLIC_KEY in GitHub Secrets"
echo "3. Deploy infrastructure with Terraform"
echo "4. Use ./setup-kubeconfig.sh to download kubeconfig"