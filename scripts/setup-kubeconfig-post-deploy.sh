#!/bin/bash
# Setup kubeconfig after infrastructure deployment
# Usage: ./setup-kubeconfig-post-deploy.sh <network_tier>

set -e

NETWORK_TIER="${1:-lower}"

echo "🔧 Setting up kubeconfig for $NETWORK_TIER network"
echo "=================================================="

# Get cluster IP from terraform output
cd infra/two-network-setup
CLUSTER_IP=$(terraform output -raw k3s_public_ip 2>/dev/null || echo "")

if [[ -z "$CLUSTER_IP" || "$CLUSTER_IP" == "null" ]]; then
  echo "❌ Could not get cluster IP from terraform output"
  exit 1
fi

echo "🎯 Cluster IP: $CLUSTER_IP"

# Setup SSH key
echo "$SSH_PRIVATE_KEY" > /tmp/ssh_key
chmod 600 /tmp/ssh_key

# Wait for instance to be ready
echo "⏳ Waiting for K3s cluster to be ready..."
for i in {1..30}; do
  if timeout 10 ssh -i /tmp/ssh_key -o StrictHostKeyChecking=no ubuntu@$CLUSTER_IP "sudo test -f /etc/rancher/k3s/k3s.yaml" 2>/dev/null; then
    echo "✅ K3s cluster is ready"
    break
  fi
  echo "⏳ Attempt $i/30 - waiting for K3s..."
  sleep 10
done

# Download kubeconfig
echo "📥 Downloading kubeconfig from cluster..."
if ssh -i /tmp/ssh_key -o StrictHostKeyChecking=no ubuntu@$CLUSTER_IP "sudo cat /etc/rancher/k3s/k3s.yaml" > /tmp/k3s-config; then
  echo "✅ Kubeconfig downloaded"
else
  echo "❌ Failed to download kubeconfig"
  exit 1
fi

# Fix server IP
echo "🔄 Fixing server IP in kubeconfig..."
sed "s/127.0.0.1/$CLUSTER_IP/g" /tmp/k3s-config > /tmp/fixed-config

# Upload to S3
echo "☁️ Uploading kubeconfig to S3..."
S3_KEY="kubeconfig-$NETWORK_TIER.yaml"
aws s3 cp /tmp/fixed-config s3://$TF_STATE_BUCKET/$S3_KEY
echo "✅ Kubeconfig uploaded to s3://$TF_STATE_BUCKET/$S3_KEY"

# Test kubeconfig
echo "🧪 Testing kubeconfig..."
export KUBECONFIG=/tmp/fixed-config
if timeout 30 kubectl get nodes --insecure-skip-tls-verify; then
  echo "✅ Kubeconfig test successful"
else
  echo "⚠️ Kubeconfig test failed, but uploaded to S3"
fi

# Create GitHub secret (base64 encoded)
echo "🔐 Creating GitHub secret..."
SECRET_NAME=""
case "$NETWORK_TIER" in
  "lower") SECRET_NAME="KUBECONFIG_DEV" ;;
  "higher") SECRET_NAME="KUBECONFIG_PROD" ;;
  "monitoring") SECRET_NAME="KUBECONFIG_MONITORING" ;;
esac

if [[ -n "$SECRET_NAME" ]]; then
  KUBECONFIG_B64=$(base64 -w 0 /tmp/fixed-config)
  
  # Use GitHub CLI to create secret
  echo "$KUBECONFIG_B64" | gh secret set $SECRET_NAME --repo $GITHUB_REPOSITORY
  echo "✅ GitHub secret $SECRET_NAME created"
else
  echo "⚠️ Unknown network tier: $NETWORK_TIER"
fi

# Cleanup
rm -f /tmp/ssh_key /tmp/k3s-config /tmp/fixed-config

echo ""
echo "🎉 Kubeconfig setup completed!"
echo "📍 S3 location: s3://$TF_STATE_BUCKET/$S3_KEY"
echo "🔐 GitHub secret: $SECRET_NAME"