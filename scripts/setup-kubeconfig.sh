#!/bin/bash
set -e

# Usage: ./setup-kubeconfig.sh <environment> <k3s_ip>
ENVIRONMENT=${1:-dev}
K3S_IP=${2}

if [ -z "$K3S_IP" ]; then
    echo "Usage: $0 <environment> <k3s_ip>"
    echo "Example: $0 dev 1.2.3.4"
    exit 1
fi

echo "🔑 Setting up kubeconfig for $ENVIRONMENT environment"
echo "K3s IP: $K3S_IP"

# Wait for kubeconfig file to exist
echo "⏳ Waiting for kubeconfig file to be created..."
for i in {1..6}; do
    echo "Checking for kubeconfig file (attempt $i/6)..."
    if ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no ubuntu@$K3S_IP "test -f /etc/rancher/k3s/k3s.yaml"; then
        echo "✅ Kubeconfig file exists"
        break
    elif [ $i -eq 6 ]; then
        echo "❌ Kubeconfig file not found after 1 minute"
        exit 1
    else
        echo "Kubeconfig not ready yet, waiting 10 seconds..."
        sleep 10
    fi
done

# Download kubeconfig
echo "📥 Downloading kubeconfig..."
scp -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no ubuntu@$K3S_IP:/etc/rancher/k3s/k3s.yaml ./kubeconfig-$ENVIRONMENT

# Update server IP
echo "🔧 Updating server IP..."
sed -i "s/127.0.0.1/$K3S_IP/g" ./kubeconfig-$ENVIRONMENT

# Wait for K3s API server to be ready
echo "⏳ Waiting for K3s API server to be ready..."
export KUBECONFIG=./kubeconfig-$ENVIRONMENT

for i in {1..12}; do
    echo "Testing K3s API server (attempt $i/12)..."
    if kubectl cluster-info --request-timeout=10s > /dev/null 2>&1; then
        echo "✅ K3s API server is ready!"
        kubectl get nodes
        break
    elif [ $i -eq 12 ]; then
        echo "❌ K3s API server not ready after 2 minutes"
        echo "🔍 Checking K3s service status via SSH..."
        ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no ubuntu@$K3S_IP "sudo systemctl status k3s --no-pager" || true
        echo "🔍 Checking K3s logs..."
        ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no ubuntu@$K3S_IP "sudo journalctl -u k3s --no-pager -n 10" || true
        exit 1
    else
        echo "K3s not ready yet, waiting 10 seconds..."
        sleep 10
    fi
done

# Create GitHub secret
if [ -n "$GITHUB_TOKEN" ]; then
    echo "🔐 Creating GitHub secret..."
    KUBECONFIG_B64=$(base64 -w 0 ./kubeconfig-$ENVIRONMENT)
    
    curl -X PUT \
        -H "Authorization: token $GITHUB_TOKEN" \
        -H "Accept: application/vnd.github.v3+json" \
        "https://api.github.com/repos/$GITHUB_REPOSITORY/actions/secrets/KUBECONFIG_${ENVIRONMENT^^}" \
        -d "{\"encrypted_value\":\"$KUBECONFIG_B64\"}"
    
    echo "✅ GitHub secret KUBECONFIG_${ENVIRONMENT^^} created"
else
    echo "⚠️ GITHUB_TOKEN not set, skipping GitHub secret creation"
fi

echo "🎉 Kubeconfig setup completed for $ENVIRONMENT"