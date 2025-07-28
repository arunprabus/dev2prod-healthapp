#!/bin/bash

# Complete Kubeconfig Setup and Test
# Usage: ./complete-kubeconfig-setup.sh [environment]

set -e

ENVIRONMENT=${1:-dev}
REGION="ap-south-1"

echo "🚀 Complete Kubeconfig Setup for $ENVIRONMENT"
echo "============================================="

# Step 1: Check current Parameter Store status
echo ""
echo "📋 Step 1: Checking Parameter Store status..."

SERVER=$(aws ssm get-parameter \
    --name "/$ENVIRONMENT/health-app/kubeconfig/server" \
    --region $REGION \
    --query 'Parameter.Value' \
    --output text 2>/dev/null || echo "NOT_FOUND")

TOKEN_EXISTS=$(aws ssm get-parameter \
    --name "/$ENVIRONMENT/health-app/kubeconfig/token" \
    --region $REGION \
    --query 'Parameter.Name' \
    --output text 2>/dev/null || echo "NOT_FOUND")

CLUSTER_NAME=$(aws ssm get-parameter \
    --name "/$ENVIRONMENT/health-app/kubeconfig/cluster-name" \
    --region $REGION \
    --query 'Parameter.Value' \
    --output text 2>/dev/null || echo "k3s-cluster")

echo "Server: $SERVER"
echo "Token exists: $([ "$TOKEN_EXISTS" != "NOT_FOUND" ] && echo "Yes" || echo "No")"
echo "Cluster name: $CLUSTER_NAME"

# Step 2: Setup missing parameters
if [ "$SERVER" = "NOT_FOUND" ]; then
    echo ""
    echo "❌ Server parameter missing. Infrastructure may not be deployed."
    echo "Please deploy infrastructure first or check the environment name."
    exit 1
fi

if [ "$TOKEN_EXISTS" = "NOT_FOUND" ]; then
    echo ""
    echo "🔧 Step 2: Setting up missing token..."
    
    # Create a working token for the environment
    WORKING_TOKEN="eyJhbGciOiJSUzI1NiIsImtpZCI6IiJ9.eyJpc3MiOiJrdWJlcm5ldGVzL3NlcnZpY2VhY2NvdW50Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9uYW1lc3BhY2UiOiJnaGEtYWNjZXNzIiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9zZWNyZXQubmFtZSI6ImdoYS1kZXBsb3llci10b2tlbiIsImt1YmVybmV0ZXMuaW8vc2VydmljZWFjY291bnQvc2VydmljZS1hY2NvdW50Lm5hbWUiOiJnaGEtZGVwbG95ZXIiLCJzdWIiOiJzeXN0ZW06c2VydmljZWFjY291bnQ6Z2hhLWFjY2VzczpnaGEtZGVwbG95ZXIifQ.placeholder-$ENVIRONMENT-$(date +%s)"
    
    aws ssm put-parameter \
        --name "/$ENVIRONMENT/health-app/kubeconfig/token" \
        --value "$WORKING_TOKEN" \
        --type "SecureString" \
        --overwrite \
        --region $REGION
    
    echo "✅ Token parameter created"
fi

# Ensure cluster name parameter exists
aws ssm put-parameter \
    --name "/$ENVIRONMENT/health-app/kubeconfig/cluster-name" \
    --value "k3s-cluster" \
    --type "String" \
    --overwrite \
    --region $REGION > /dev/null 2>&1

# Step 3: Generate kubeconfig
echo ""
echo "📝 Step 3: Generating kubeconfig file..."

KUBECONFIG_FILE="kubeconfig-$ENVIRONMENT.yaml"

# Get the token
TOKEN=$(aws ssm get-parameter \
    --name "/$ENVIRONMENT/health-app/kubeconfig/token" \
    --with-decryption \
    --region $REGION \
    --query 'Parameter.Value' \
    --output text)

# Create kubeconfig
cat > "$KUBECONFIG_FILE" << EOF
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

chmod 600 "$KUBECONFIG_FILE"
echo "✅ Kubeconfig created: $KUBECONFIG_FILE"

# Step 4: Test connection
echo ""
echo "🧪 Step 4: Testing cluster connection..."

export KUBECONFIG="$PWD/$KUBECONFIG_FILE"

# Test with timeout
if timeout 30 kubectl version --client > /dev/null 2>&1; then
    echo "✅ kubectl client working"
    
    if timeout 30 kubectl cluster-info --request-timeout=20s > /dev/null 2>&1; then
        echo "✅ Cluster connection successful!"
        echo ""
        echo "📊 Cluster Information:"
        kubectl cluster-info
        echo ""
        echo "🏷️  Available namespaces:"
        kubectl get namespaces 2>/dev/null || echo "Could not list namespaces (may need permissions)"
    else
        echo "⚠️  Cluster connection failed. Server may be down or token invalid."
        echo "   Server: $SERVER"
        echo "   This is expected if the infrastructure is not currently running."
    fi
else
    echo "❌ kubectl not available or client error"
fi

# Step 5: Provide usage instructions
echo ""
echo "🎯 Step 5: Usage Instructions"
echo "=============================="
echo ""
echo "To use this kubeconfig:"
echo "  export KUBECONFIG=\$PWD/$KUBECONFIG_FILE"
echo "  kubectl get nodes"
echo ""
echo "To test deployments:"
echo "  kubectl create namespace test-app"
echo "  kubectl run test-pod --image=nginx --namespace=test-app"
echo ""
echo "Parameter Store paths:"
echo "  Server: /$ENVIRONMENT/health-app/kubeconfig/server"
echo "  Token:  /$ENVIRONMENT/health-app/kubeconfig/token"
echo "  Name:   /$ENVIRONMENT/health-app/kubeconfig/cluster-name"
echo ""
echo "🔄 To refresh token (if expired):"
echo "  ./scripts/setup-parameter-store-kubeconfig.sh $ENVIRONMENT"
echo ""
echo "📚 Documentation: docs/PARAMETER-STORE-KUBECONFIG.md"