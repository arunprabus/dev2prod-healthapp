#!/bin/bash

# Get Kubeconfig from Parameter Store
# Usage: ./get-kubeconfig-from-parameter-store.sh <environment> [output-file]

set -e

ENVIRONMENT=${1}
OUTPUT_FILE=${2:-"kubeconfig-${ENVIRONMENT}.yaml"}
REGION="ap-south-1"

if [ -z "$ENVIRONMENT" ]; then
    echo "❌ Error: Environment is required"
    echo "Usage: $0 <environment> [output-file]"
    echo "Example: $0 dev kubeconfig-dev.yaml"
    exit 1
fi

echo "🔧 Retrieving kubeconfig for $ENVIRONMENT environment from Parameter Store..."

# Get kubeconfig data from Parameter Store
echo "📥 Fetching kubeconfig parameters..."

SERVER=$(aws ssm get-parameter \
    --name "/$ENVIRONMENT/health-app/kubeconfig/server" \
    --region $REGION \
    --query 'Parameter.Value' \
    --output text 2>/dev/null || echo "")

TOKEN=$(aws ssm get-parameter \
    --name "/$ENVIRONMENT/health-app/kubeconfig/token" \
    --with-decryption \
    --region $REGION \
    --query 'Parameter.Value' \
    --output text 2>/dev/null || echo "")

CLUSTER_NAME=$(aws ssm get-parameter \
    --name "/$ENVIRONMENT/health-app/kubeconfig/cluster-name" \
    --region $REGION \
    --query 'Parameter.Value' \
    --output text 2>/dev/null || echo "k3s-cluster")

if [ -z "$SERVER" ] || [ -z "$TOKEN" ]; then
    echo "❌ Error: Could not retrieve kubeconfig data from Parameter Store"
    echo "   Make sure the cluster is deployed and kubeconfig is stored"
    echo "   Parameters checked:"
    echo "   - /$ENVIRONMENT/health-app/kubeconfig/server"
    echo "   - /$ENVIRONMENT/health-app/kubeconfig/token"
    exit 1
fi

echo "✅ Retrieved kubeconfig parameters:"
echo "   Server: $SERVER"
echo "   Cluster: $CLUSTER_NAME"

# Create kubeconfig file
cat > "$OUTPUT_FILE" << EOF
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

# Set permissions
chmod 600 "$OUTPUT_FILE"

echo "✅ Kubeconfig created: $OUTPUT_FILE"

# Test connection
echo "🧪 Testing connection..."
export KUBECONFIG="$PWD/$OUTPUT_FILE"

if timeout 30 kubectl get nodes --request-timeout=20s > /dev/null 2>&1; then
    echo "✅ Connection successful!"
    kubectl get nodes
else
    echo "⚠️  Connection test failed. Kubeconfig created but cluster may not be ready."
    echo "   Try again in a few minutes or check cluster status."
fi

echo ""
echo "🚀 To use this kubeconfig:"
echo "export KUBECONFIG=\$PWD/$OUTPUT_FILE"
echo "kubectl get nodes"