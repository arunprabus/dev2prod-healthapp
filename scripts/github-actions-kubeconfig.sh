#!/bin/bash

# GitHub Actions Kubeconfig Setup using Parameter Store
# Usage: ./github-actions-kubeconfig.sh <environment>

set -e

ENVIRONMENT=${1}
REGION="ap-south-1"

if [ -z "$ENVIRONMENT" ]; then
    echo "❌ Error: Environment is required"
    echo "Usage: $0 <environment>"
    exit 1
fi

echo "🔧 Setting up kubeconfig for GitHub Actions from Parameter Store..."

# Get kubeconfig data from Parameter Store
SERVER=$(aws ssm get-parameter \
    --name "/$ENVIRONMENT/health-app/kubeconfig/server" \
    --region $REGION \
    --query 'Parameter.Value' \
    --output text)

TOKEN=$(aws ssm get-parameter \
    --name "/$ENVIRONMENT/health-app/kubeconfig/token" \
    --with-decryption \
    --region $REGION \
    --query 'Parameter.Value' \
    --output text)

CLUSTER_NAME=$(aws ssm get-parameter \
    --name "/$ENVIRONMENT/health-app/kubeconfig/cluster-name" \
    --region $REGION \
    --query 'Parameter.Value' \
    --output text 2>/dev/null || echo "k3s-cluster")

# Create kubeconfig
cat > kubeconfig.yaml << EOF
apiVersion: v1
kind: Config
clusters:
- cluster:
    insecure-skip-tls-verify: true
    server: $SERVER
  name: $CLUSTER_NAME
contexts:
- context:
    cluster: $CLUSTER_NAME
    namespace: gha-access
    user: gha-deployer
  name: gha-context
current-context: gha-context
users:
- name: gha-deployer
  user:
    token: $TOKEN
EOF

# Set as environment variable for GitHub Actions
echo "KUBECONFIG_CONTENT<<EOF" >> $GITHUB_ENV
cat kubeconfig.yaml >> $GITHUB_ENV
echo "EOF" >> $GITHUB_ENV

echo "✅ Kubeconfig set for GitHub Actions"