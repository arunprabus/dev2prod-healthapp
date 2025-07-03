#!/bin/bash

# Generate kubeconfig for each network/environment
# Usage: ./generate-kubeconfig.sh <environment> <cluster-ip>

set -e

ENVIRONMENT=${1}
CLUSTER_IP=${2}

if [[ -z "$ENVIRONMENT" || -z "$CLUSTER_IP" ]]; then
    echo "Usage: $0 <environment> <cluster-ip>"
    echo "Examples:"
    echo "  $0 lower 1.2.3.4"
    echo "  $0 higher 5.6.7.8"
    echo "  $0 monitoring 9.10.11.12"
    exit 1
fi

echo "🔧 Generating kubeconfig for $ENVIRONMENT environment"
echo "🌐 Cluster IP: $CLUSTER_IP"

# Test SSH connection
echo "🔍 Testing SSH connection..."
if ! ssh -i ~/.ssh/aws-key -o ConnectTimeout=10 -o StrictHostKeyChecking=no ubuntu@$CLUSTER_IP "echo 'Connected'" 2>/dev/null; then
    echo "❌ SSH connection failed"
    echo "💡 Ensure:"
    echo "   1. SSH key exists: ~/.ssh/aws-key"
    echo "   2. Cluster is running: $CLUSTER_IP"
    echo "   3. Security group allows SSH (port 22)"
    exit 1
fi

# Get K3s token
echo "🔑 Retrieving K3s token..."
K3S_TOKEN=$(ssh -i ~/.ssh/aws-key -o StrictHostKeyChecking=no ubuntu@$CLUSTER_IP 'sudo cat /var/lib/rancher/k3s/server/node-token' 2>/dev/null)

if [[ -z "$K3S_TOKEN" ]]; then
    echo "❌ Failed to get K3s token"
    echo "💡 K3s may not be ready. Wait 2-3 minutes after deployment."
    exit 1
fi

# Generate kubeconfig
mkdir -p ~/.kube
cat > ~/.kube/config-$ENVIRONMENT << EOF
apiVersion: v1
kind: Config
clusters:
- cluster:
    server: https://$CLUSTER_IP:6443
    insecure-skip-tls-verify: true
  name: health-app-$ENVIRONMENT
contexts:
- context:
    cluster: health-app-$ENVIRONMENT
    user: health-app-$ENVIRONMENT
  name: health-app-$ENVIRONMENT
current-context: health-app-$ENVIRONMENT
users:
- name: health-app-$ENVIRONMENT
  user:
    token: $K3S_TOKEN
EOF

# Generate base64 for GitHub Secrets
SECRET_NAME="KUBECONFIG_$(echo $ENVIRONMENT | tr '[:lower:]' '[:upper:]')"
BASE64_CONFIG=$(base64 -w 0 ~/.kube/config-$ENVIRONMENT)

echo ""
echo "✅ Kubeconfig generated successfully!"
echo ""
echo "📋 Add to GitHub Secrets:"
echo "   Name: $SECRET_NAME"
echo "   Value: $BASE64_CONFIG"
echo ""
echo "🔗 Steps:"
echo "   1. Go to Settings → Secrets and variables → Actions"
echo "   2. Click 'New repository secret'"
echo "   3. Name: $SECRET_NAME"
echo "   4. Secret: Copy the base64 value above"
echo "   5. Click 'Add secret'"
echo ""
echo "🧪 Test locally:"
echo "   export KUBECONFIG=~/.kube/config-$ENVIRONMENT"
echo "   kubectl get nodes"