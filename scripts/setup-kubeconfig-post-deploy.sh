#!/bin/bash
# Setup kubeconfig after infrastructure deployment
# Usage: ./setup-kubeconfig-post-deploy.sh <network_tier> <ssh_private_key_file>

set -euo pipefail

NETWORK_TIER="${1:-}"
SSH_KEY_FILE="${2:-}"

if [[ -z "$NETWORK_TIER" ]]; then
  echo "Usage: $0 <network_tier> [ssh_private_key_file]"
  echo "Example: $0 lower ~/.ssh/k3s-key"
  exit 1
fi

echo "🔧 Setting up kubeconfig for $NETWORK_TIER network..."

# Get cluster IP from terraform output
cd infra/two-network-setup
echo "🔍 Getting cluster IP from terraform..."

# Show all outputs for debugging
echo "Available terraform outputs:"
terraform output 2>/dev/null || echo "No outputs available"

# Try multiple ways to get the cluster IP
CLUSTER_IP=""
if terraform output k8s_master_public_ip >/dev/null 2>&1; then
  CLUSTER_IP=$(terraform output -raw k8s_master_public_ip 2>/dev/null)
elif terraform output k8s_public_ip >/dev/null 2>&1; then
  CLUSTER_IP=$(terraform output -raw k8s_public_ip 2>/dev/null)
else
  # Try JSON output
  CLUSTER_IP=$(terraform output -json 2>/dev/null | jq -r '.k8s_master_public_ip.value // .k8s_public_ip.value // empty' 2>/dev/null)
fi

if [[ -z "$CLUSTER_IP" || "$CLUSTER_IP" == "null" || "$CLUSTER_IP" == *"error"* ]]; then
  echo "❌ No valid cluster IP found in terraform output"
  echo "Cluster IP value: '$CLUSTER_IP'"
  exit 1
fi

echo "🎯 Found cluster IP: $CLUSTER_IP"

# Setup SSH key
if [[ -n "$SSH_KEY_FILE" && -f "$SSH_KEY_FILE" ]]; then
  SSH_KEY="$SSH_KEY_FILE"
elif [[ -n "${SSH_PRIVATE_KEY:-}" ]]; then
  # Use environment variable (from GitHub secrets)
  echo "$SSH_PRIVATE_KEY" > /tmp/ssh_key
  chmod 600 /tmp/ssh_key
  SSH_KEY="/tmp/ssh_key"
else
  echo "❌ No SSH key provided. Use:"
  echo "  - Pass SSH key file as second argument"
  echo "  - Set SSH_PRIVATE_KEY environment variable"
  exit 1
fi

# Wait for SSH access
echo "🔍 Waiting for SSH access..."
for i in {1..10}; do
  if ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no -o ConnectTimeout=10 ubuntu@$CLUSTER_IP "echo 'SSH ready'" 2>/dev/null; then
    echo "✅ SSH connection established"
    break
  fi
  echo "⏳ Attempt $i/10 - waiting for SSH..."
  sleep 10
done

# Download kubeconfig
echo "📥 Downloading kubeconfig from cluster..."
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ubuntu@$CLUSTER_IP \
  "sudo cat /etc/rancher/k3s/k3s.yaml" > /tmp/kubeconfig_raw.yaml

# Update server IP
echo "🔧 Updating kubeconfig server IP..."
sed "s/127.0.0.1/$CLUSTER_IP/g" /tmp/kubeconfig_raw.yaml > /tmp/kubeconfig.yaml

# Test connection
echo "🧪 Testing connection..."
export KUBECONFIG=/tmp/kubeconfig.yaml

if timeout 30s kubectl get nodes --request-timeout=20s >/dev/null 2>&1; then
  echo "✅ Connection successful!"
  kubectl get nodes
else
  echo "⚠️ Connection test failed but kubeconfig created"
fi

# Generate base64 for GitHub secret
KUBECONFIG_B64=$(base64 -w 0 /tmp/kubeconfig.yaml)

# Map environment to secret name
case "$NETWORK_TIER" in
  "lower")
    SECRET_NAME="KUBECONFIG_DEV"
    ;;
  "higher")
    SECRET_NAME="KUBECONFIG_PROD"
    ;;
  "monitoring")
    SECRET_NAME="KUBECONFIG_MONITORING"
    ;;
  *)
    SECRET_NAME="KUBECONFIG_${NETWORK_TIER^^}"
    ;;
esac

echo ""
echo "🔐 Kubeconfig Setup Complete!"
echo "📋 Manual Secret Setup Required:"
echo "1. Go to Settings → Secrets and variables → Actions"
echo "2. Click 'New repository secret'"
echo "3. Name: $SECRET_NAME"
echo "4. Value: (copy from below)"
echo ""
echo "--- COPY THIS VALUE ---"
echo "$KUBECONFIG_B64"
echo "--- END VALUE ---"
echo ""

# Save to file for convenience
echo "$KUBECONFIG_B64" > "/tmp/kubeconfig_${NETWORK_TIER}_b64.txt"
cp /tmp/kubeconfig.yaml "/tmp/kubeconfig_${NETWORK_TIER}.yaml"

echo "📁 Files saved:"
echo "  - Kubeconfig: /tmp/kubeconfig_${NETWORK_TIER}.yaml"
echo "  - Base64: /tmp/kubeconfig_${NETWORK_TIER}_b64.txt"

# Cleanup
rm -f /tmp/ssh_key /tmp/kubeconfig_raw.yaml /tmp/kubeconfig.yaml

echo "✅ Kubeconfig setup completed for $NETWORK_TIER"