#!/bin/bash

# Test Parameter Store and Kubeconfig after redeploy
# Usage: ./test-after-redeploy.sh [environment]

ENVIRONMENT=${1:-dev}
REGION="ap-south-1"

echo "🔄 Testing after redeploy for $ENVIRONMENT environment"
echo "=================================================="

# Step 1: Check if infrastructure is running
echo ""
echo "🏗️ Step 1: Checking infrastructure status..."
INSTANCE_ID=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=health-app-lower-$ENVIRONMENT" "Name=instance-state-name,Values=running" \
    --query 'Reservations[0].Instances[0].InstanceId' \
    --output text 2>/dev/null || echo "None")

if [ "$INSTANCE_ID" != "None" ]; then
    PUBLIC_IP=$(aws ec2 describe-instances \
        --instance-ids $INSTANCE_ID \
        --query 'Reservations[0].Instances[0].PublicIpAddress' \
        --output text)
    echo "✅ Infrastructure running: $INSTANCE_ID"
    echo "📡 Public IP: $PUBLIC_IP"
else
    echo "❌ No running infrastructure found"
    echo "Please wait for deployment to complete or check deployment status"
    exit 1
fi

# Step 2: Check Parameter Store
echo ""
echo "📋 Step 2: Checking Parameter Store parameters..."

# List all health-app parameters
echo "Available parameters:"
aws ssm get-parameters-by-path \
    --path "/$ENVIRONMENT/health-app/" \
    --region $REGION \
    --query 'Parameters[*].[Name,Type]' \
    --output table

# Check specific kubeconfig parameters
SERVER=$(aws ssm get-parameter \
    --name "/$ENVIRONMENT/health-app/kubeconfig/server" \
    --region $REGION \
    --output json 2>/dev/null | jq -r '.Parameter.Value' || echo "NOT_FOUND")

TOKEN_EXISTS=$(aws ssm get-parameter \
    --name "/$ENVIRONMENT/health-app/kubeconfig/token" \
    --region $REGION \
    --output json 2>/dev/null | jq -r '.Parameter.Name' || echo "NOT_FOUND")

echo ""
echo "Kubeconfig parameters:"
echo "  Server: $SERVER"
echo "  Token: $([ "$TOKEN_EXISTS" != "NOT_FOUND" ] && echo "EXISTS" || echo "MISSING")"

# Step 3: Test kubeconfig if parameters exist
if [ "$SERVER" != "NOT_FOUND" ] && [ "$TOKEN_EXISTS" != "NOT_FOUND" ]; then
    echo ""
    echo "🔑 Step 3: Creating and testing kubeconfig..."
    
    # Get token value
    TOKEN=$(aws ssm get-parameter \
        --name "/$ENVIRONMENT/health-app/kubeconfig/token" \
        --with-decryption \
        --region $REGION \
        --output json | jq -r '.Parameter.Value')
    
    # Create kubeconfig
    KUBECONFIG_FILE="kubeconfig-$ENVIRONMENT-test.yaml"
    cat > "$KUBECONFIG_FILE" << EOF
apiVersion: v1
kind: Config
clusters:
- cluster:
    insecure-skip-tls-verify: true
    server: $SERVER
  name: k3s-cluster
contexts:
- context:
    cluster: k3s-cluster
    namespace: default
    user: admin
  name: default
current-context: default
users:
- name: admin
  user:
    token: $TOKEN
EOF
    
    chmod 600 "$KUBECONFIG_FILE"
    echo "✅ Kubeconfig created: $KUBECONFIG_FILE"
    
    # Test connection
    echo ""
    echo "🧪 Testing cluster connection..."
    export KUBECONFIG="$PWD/$KUBECONFIG_FILE"
    
    if timeout 30 kubectl version --client > /dev/null 2>&1; then
        echo "✅ kubectl client working"
        
        if timeout 30 kubectl cluster-info --request-timeout=20s 2>/dev/null; then
            echo "✅ Cluster connection successful!"
            echo ""
            echo "📊 Cluster status:"
            kubectl get nodes 2>/dev/null || echo "Could not get nodes (may need permissions)"
        else
            echo "⚠️  Cluster connection failed - server may still be starting"
            echo "   Server: $SERVER"
            echo "   Try again in a few minutes"
        fi
    else
        echo "❌ kubectl not available"
    fi
else
    echo ""
    echo "⚠️  Step 3: Kubeconfig parameters missing"
    echo "   Run setup script after deployment completes:"
    echo "   ./scripts/setup-parameter-store-kubeconfig.sh $ENVIRONMENT"
fi

echo ""
echo "🎯 Summary for $ENVIRONMENT:"
echo "=========================="
echo "Infrastructure: $([ "$INSTANCE_ID" != "None" ] && echo "✅ Running" || echo "❌ Missing")"
echo "Server param:   $([ "$SERVER" != "NOT_FOUND" ] && echo "✅ Found" || echo "❌ Missing")"
echo "Token param:    $([ "$TOKEN_EXISTS" != "NOT_FOUND" ] && echo "✅ Found" || echo "❌ Missing")"
echo ""
echo "Next steps:"
echo "1. If parameters missing: ./scripts/setup-parameter-store-kubeconfig.sh $ENVIRONMENT"
echo "2. If connection fails: Wait for cluster to fully start (5-10 minutes)"
echo "3. Manual test: export KUBECONFIG=\$PWD/$KUBECONFIG_FILE && kubectl get nodes"