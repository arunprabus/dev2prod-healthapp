#!/bin/bash
# Combined kubeconfig fix and health check
# Usage: ./kubeconfig-fix-and-test.sh <environment> <cluster_ip>

set -e

ENVIRONMENT="${1:-dev}"
CLUSTER_IP="${2:-}"

if [[ -z "$CLUSTER_IP" ]]; then
  echo "❌ Usage: $0 <environment> <cluster_ip>"
  echo "Example: $0 dev 43.205.211.129"
  exit 1
fi

echo "🔧 Kubeconfig Fix & Test for $ENVIRONMENT"
echo "=========================================="

# Step 1: Fix kubeconfig
echo "📥 Step 1: Downloading and fixing kubeconfig..."
if [[ -z "${SSH_PRIVATE_KEY:-}" ]]; then
  echo "❌ SSH_PRIVATE_KEY environment variable not set"
  exit 1
fi

echo "$SSH_PRIVATE_KEY" > /tmp/ssh_key
chmod 600 /tmp/ssh_key

# Download kubeconfig using sudo with timeout
echo "Connecting to $CLUSTER_IP..."
echo "🔍 Testing SSH connection first..."
ssh -i /tmp/ssh_key -o StrictHostKeyChecking=no -o ConnectTimeout=10 ubuntu@$CLUSTER_IP "echo 'SSH connection successful'" || { echo "❌ SSH connection failed"; exit 1; }

echo "📁 Checking if K3s config file exists..."
ssh -i /tmp/ssh_key -o StrictHostKeyChecking=no ubuntu@$CLUSTER_IP "sudo ls -la /etc/rancher/k3s/k3s.yaml" || { echo "❌ K3s config file not found"; exit 1; }

echo "📥 Downloading kubeconfig..."
if ssh -i /tmp/ssh_key -o StrictHostKeyChecking=no ubuntu@$CLUSTER_IP "sudo cat /etc/rancher/k3s/k3s.yaml" > /tmp/k3s-config; then
  echo "✅ Kubeconfig downloaded successfully"
else
  echo "❌ Failed to download kubeconfig"
  echo "🔍 Checking K3s service status..."
  ssh -i /tmp/ssh_key -o StrictHostKeyChecking=no ubuntu@$CLUSTER_IP "sudo systemctl status k3s --no-pager -l" || echo "K3s service check failed"
  exit 1
fi
sed "s/127.0.0.1/$CLUSTER_IP/g" /tmp/k3s-config > /tmp/fixed-config

mkdir -p ~/.kube
cp /tmp/fixed-config ~/.kube/config
chmod 600 ~/.kube/config

echo "✅ Kubeconfig fixed and installed"

# Step 2: Test kubectl connection
echo ""
echo "🧪 Step 2: Testing kubectl connection..."
if kubectl get nodes; then
  echo "✅ kubectl connection successful!"
  echo ""
  echo "📊 Cluster info:"
  kubectl cluster-info
  echo ""
  echo "🐳 System pods:"
  kubectl get pods -A --field-selector=metadata.namespace!=kube-system | head -10
else
  echo "❌ kubectl connection failed"
  echo ""
  echo "🔍 Running health check for diagnostics..."
  ./k8s-cluster-health-check.sh $ENVIRONMENT $CLUSTER_IP
  exit 1
fi

# Cleanup
rm -f /tmp/ssh_key /tmp/k3s-config /tmp/fixed-config

echo ""
echo "🎉 Kubeconfig fix and test completed successfully!"