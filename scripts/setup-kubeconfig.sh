#!/bin/bash

# Setup kubeconfig for K8s cluster access
set -e

ENVIRONMENT=${1:-"dev"}
CLUSTER_IP=${2}

if [[ -z "$CLUSTER_IP" ]]; then
    echo "Usage: $0 <environment> <cluster-ip>"
    echo "Example: $0 dev 1.2.3.4"
    exit 1
fi

echo "🔧 Setting up kubeconfig for $ENVIRONMENT environment"

# Create kubeconfig
mkdir -p ~/.kube

# Get K3s token via SSH
echo "🔑 Retrieving K3s token from cluster..."
K3S_TOKEN=$(ssh -i ~/.ssh/aws-key -o ConnectTimeout=30 -o StrictHostKeyChecking=no ubuntu@$CLUSTER_IP 'sudo cat /var/lib/rancher/k3s/server/node-token' 2>/dev/null || echo "TOKEN_ERROR")

if [[ "$K3S_TOKEN" == "TOKEN_ERROR" || -z "$K3S_TOKEN" ]]; then
    echo "❌ Failed to retrieve K3s token from cluster"
    echo "💡 Cluster may not be ready or SSH access failed"
    echo "🔗 Manual setup required:"
    echo "   ssh -i ~/.ssh/aws-key ubuntu@$CLUSTER_IP"
    echo "   sudo cat /var/lib/rancher/k3s/server/node-token"
    exit 1
fi

# Create kubeconfig
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

# Encode for GitHub Secrets
echo "📋 Base64 encoded kubeconfig for GitHub Secrets:"
base64 -w 0 ~/.kube/config-$ENVIRONMENT

echo ""
echo "✅ Kubeconfig created: ~/.kube/config-$ENVIRONMENT"
echo "💡 Add the base64 output to GitHub Secrets as KUBECONFIG_$ENVIRONMENT"