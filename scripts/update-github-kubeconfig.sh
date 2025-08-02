#!/bin/bash

# Script to generate kubeconfig and update GitHub secrets
# Usage: ./update-github-kubeconfig.sh <environment> <k3s_ip> <github_token> <repo_name>

set -e

ENVIRONMENT=$1
K3S_IP=$2
GITHUB_TOKEN=$3
REPO_NAME=$4

if [ -z "$ENVIRONMENT" ] || [ -z "$K3S_IP" ] || [ -z "$GITHUB_TOKEN" ] || [ -z "$REPO_NAME" ]; then
    echo "Usage: $0 <environment> <k3s_ip> <github_token> <repo_name>"
    exit 1
fi

echo "🔧 Generating kubeconfig for $ENVIRONMENT environment..."

# Download kubeconfig from K3s node
ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no ubuntu@$K3S_IP "sudo cat /etc/rancher/k3s/k3s.yaml" > /tmp/kubeconfig-$ENVIRONMENT.yaml

# Update server IP in kubeconfig
sed -i "s/127.0.0.1/$K3S_IP/g" /tmp/kubeconfig-$ENVIRONMENT.yaml

# Test kubeconfig
if kubectl --kubeconfig=/tmp/kubeconfig-$ENVIRONMENT.yaml get nodes > /dev/null 2>&1; then
    echo "✅ Kubeconfig is valid"
else
    echo "❌ Kubeconfig validation failed"
    exit 1
fi

# Base64 encode kubeconfig
KUBECONFIG_B64=$(base64 -w 0 /tmp/kubeconfig-$ENVIRONMENT.yaml)

# Update GitHub secret
SECRET_NAME="KUBECONFIG_$(echo $ENVIRONMENT | tr '[:lower:]' '[:upper:]')"

# Get repository ID
REPO_ID=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
    "https://api.github.com/repos/$REPO_NAME" | jq -r '.id')

# Get public key for encryption
PUBLIC_KEY_RESPONSE=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
    "https://api.github.com/repos/$REPO_NAME/actions/secrets/public-key")

PUBLIC_KEY=$(echo $PUBLIC_KEY_RESPONSE | jq -r '.key')
KEY_ID=$(echo $PUBLIC_KEY_RESPONSE | jq -r '.key_id')

# Encrypt the secret (using Python for simplicity)
python3 -c "
import base64
import json
from nacl import encoding, public

def encrypt_secret(public_key: str, secret_value: str) -> str:
    public_key = public.PublicKey(public_key.encode('utf-8'), encoding.Base64Encoder())
    sealed_box = public.SealedBox(public_key)
    encrypted = sealed_box.encrypt(secret_value.encode('utf-8'))
    return base64.b64encode(encrypted).decode('utf-8')

encrypted_value = encrypt_secret('$PUBLIC_KEY', '$KUBECONFIG_B64')
print(encrypted_value)
" > /tmp/encrypted_secret.txt

ENCRYPTED_VALUE=$(cat /tmp/encrypted_secret.txt)

# Update the secret
curl -X PUT \
    -H "Authorization: token $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github.v3+json" \
    "https://api.github.com/repos/$REPO_NAME/actions/secrets/$SECRET_NAME" \
    -d "{\"encrypted_value\":\"$ENCRYPTED_VALUE\",\"key_id\":\"$KEY_ID\"}"

echo "✅ Updated GitHub secret: $SECRET_NAME"

# Cleanup
rm -f /tmp/kubeconfig-$ENVIRONMENT.yaml /tmp/encrypted_secret.txt

echo "🎉 Kubeconfig setup completed for $ENVIRONMENT"