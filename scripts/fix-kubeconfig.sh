#!/bin/bash
# Fix kubeconfig by downloading from K3s cluster
# Usage: ./fix-kubeconfig.sh <cluster_ip>

set -e

CLUSTER_IP="${1:-}"

if [[ -z "$CLUSTER_IP" ]]; then
  echo "❌ Usage: $0 <cluster_ip>"
  echo "Example: $0 43.205.211.129"
  exit 1
fi

echo "🔧 Fixing kubeconfig for cluster: $CLUSTER_IP"

# Check if SSH key is available
if [[ -z "${SSH_PRIVATE_KEY:-}" ]]; then
  echo "❌ SSH_PRIVATE_KEY environment variable not set"
  exit 1
fi

# Create SSH key file
echo "$SSH_PRIVATE_KEY" > /tmp/ssh_key
chmod 600 /tmp/ssh_key

# Download kubeconfig from cluster
echo "📥 Downloading kubeconfig from cluster..."
ssh -i /tmp/ssh_key -o StrictHostKeyChecking=no ubuntu@$CLUSTER_IP "sudo cat /etc/rancher/k3s/k3s.yaml" > /tmp/k3s-config

# Fix server IP (replace 127.0.0.1 with actual cluster IP)
echo "🔄 Updating server IP to $CLUSTER_IP..."
sed "s/127.0.0.1/$CLUSTER_IP/g" /tmp/k3s-config > /tmp/fixed-config

# Create .kube directory and copy config
mkdir -p ~/.kube
cp /tmp/fixed-config ~/.kube/config
chmod 600 ~/.kube/config

# Test connection
echo "🧪 Testing kubectl connection..."
if kubectl get nodes; then
  echo "✅ kubectl configured successfully!"
else
  echo "❌ kubectl test failed"
  exit 1
fi

# Cleanup
rm -f /tmp/ssh_key /tmp/k3s-config /tmp/fixed-config

echo "🎉 kubeconfig fixed and ready to use"