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

# Download kubeconfig
echo "📥 Downloading kubeconfig..."
scp -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no ubuntu@$K3S_IP:/etc/rancher/k3s/k3s.yaml ./kubeconfig-$ENVIRONMENT

# Update server IP
echo "🔧 Updating server IP..."
sed -i "s/127.0.0.1/$K3S_IP/g" ./kubeconfig-$ENVIRONMENT

# Test connection
echo "🧪 Testing connection..."
export KUBECONFIG=./kubeconfig-$ENVIRONMENT
if kubectl cluster-info --request-timeout=10s > /dev/null 2>&1; then
    echo "✅ Kubeconfig is working"
    kubectl get nodes
else
    echo "❌ Kubeconfig test failed"
    exit 1
fi

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