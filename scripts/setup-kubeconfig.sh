#!/bin/bash

# Setup Kubeconfig Script
# Usage: ./setup-kubeconfig.sh <environment> <public-ip> [ssh-key-path]

set -e

ENVIRONMENT=${1:-dev}
PUBLIC_IP=${2}
SSH_KEY=${3:-~/.ssh/k3s-key}

if [ -z "$PUBLIC_IP" ]; then
    echo "❌ Error: Public IP is required"
    echo "Usage: $0 <environment> <public-ip> [ssh-key-path]"
    echo "Example: $0 dev 1.2.3.4 ~/.ssh/k3s-key"
    exit 1
fi

echo "🔧 Setting up kubeconfig for $ENVIRONMENT environment..."
echo "📡 Cluster IP: $PUBLIC_IP"
echo "🔑 SSH Key: $SSH_KEY"

# Download kubeconfig from K3s cluster
echo "📥 Downloading kubeconfig..."
scp -i "$SSH_KEY" -o StrictHostKeyChecking=no ubuntu@"$PUBLIC_IP":/etc/rancher/k3s/k3s.yaml "kubeconfig-$ENVIRONMENT.yaml"

# Replace localhost with public IP
echo "🔄 Updating server IP in kubeconfig..."
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    sed -i '' "s/127.0.0.1/$PUBLIC_IP/" "kubeconfig-$ENVIRONMENT.yaml"
else
    # Linux
    sed -i "s/127.0.0.1/$PUBLIC_IP/" "kubeconfig-$ENVIRONMENT.yaml"
fi

# Set permissions
chmod 600 "kubeconfig-$ENVIRONMENT.yaml"

echo "✅ Kubeconfig setup complete!"
echo ""
echo "🚀 To use this kubeconfig:"
echo "export KUBECONFIG=\$PWD/kubeconfig-$ENVIRONMENT.yaml"
echo "kubectl get nodes"
echo ""
echo "📁 Kubeconfig saved as: kubeconfig-$ENVIRONMENT.yaml"

# Test connection with retries
echo "🧪 Testing connection..."
export KUBECONFIG="$PWD/kubeconfig-$ENVIRONMENT.yaml"

CONNECTION_SUCCESS=false
for i in {1..3}; do
    echo "Connection test attempt $i/3..."
    if timeout 30 kubectl get nodes --request-timeout=20s > /dev/null 2>&1; then
        echo "✅ Connection successful!"
        kubectl get nodes
        CONNECTION_SUCCESS=true
        break
    else
        echo "Connection failed, waiting 30s before retry..."
        sleep 30
    fi
done

if [ "$CONNECTION_SUCCESS" = "false" ]; then
    echo "⚠️  All connection tests failed. Please check:"
    echo "   - SSH key permissions: chmod 600 $SSH_KEY"
    echo "   - Security group allows port 6443"
    echo "   - K3s service is running on the cluster"
    echo "   - Wait a few minutes for K3s to fully initialize"
fi