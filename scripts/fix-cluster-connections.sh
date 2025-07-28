#!/bin/bash

# Fix Cluster Connection Issues using Parameter Store
# Usage: ./fix-cluster-connections.sh

set -e

echo "🔧 Fixing cluster connection issues using Parameter Store..."

# Step 1: Enable Parameter Store in infrastructure
echo "📋 Step 1: Enabling Parameter Store module..."
cd infra

# Check if Parameter Store is enabled
if grep -q "# Deploy Parameter Store for configuration management (temporarily disabled)" main.tf; then
    echo "⚠️  Parameter Store module is disabled. Please run terraform apply to enable it."
    echo "   The module has been enabled in the code."
fi

# Step 2: Setup Parameter Store for existing clusters
echo "📋 Step 2: Setting up Parameter Store for existing clusters..."
cd ../scripts

# Check if dev cluster exists
DEV_INSTANCE=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=health-app-lower-dev" "Name=instance-state-name,Values=running" \
    --query 'Reservations[0].Instances[0].InstanceId' \
    --output text 2>/dev/null || echo "None")

if [ "$DEV_INSTANCE" != "None" ]; then
    echo "✅ Found dev cluster, setting up Parameter Store..."
    ./setup-parameter-store-kubeconfig.sh dev
else
    echo "⚠️  Dev cluster not found or not running"
fi

# Check if test cluster exists
TEST_INSTANCE=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=health-app-lower-test" "Name=instance-state-name,Values=running" \
    --query 'Reservations[0].Instances[0].InstanceId' \
    --output text 2>/dev/null || echo "None")

if [ "$TEST_INSTANCE" != "None" ]; then
    echo "✅ Found test cluster, setting up Parameter Store..."
    ./setup-parameter-store-kubeconfig.sh test
else
    echo "⚠️  Test cluster not found or not running"
fi

# Step 3: Test connections
echo "📋 Step 3: Testing cluster connections..."
./test-lower-deployment.sh

echo "✅ Cluster connection fix complete!"
echo ""
echo "🚀 Next steps:"
echo "1. If clusters are not running, deploy infrastructure first:"
echo "   cd infra && terraform apply -var-file=environments/lower.tfvars"
echo "2. Test individual cluster connections:"
echo "   ./scripts/get-kubeconfig-from-parameter-store.sh dev"
echo "   ./scripts/get-kubeconfig-from-parameter-store.sh test"
echo "3. Deploy applications using GitHub Actions workflows"