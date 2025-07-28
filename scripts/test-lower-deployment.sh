#!/bin/bash

# Test Lower Infrastructure Deployment
# Usage: ./test-lower-deployment.sh

set -e

echo "🧪 Testing Lower Infrastructure Deployment..."

# Environment
ENV="lower"
CLUSTER_NAME="health-app-lower"

# Test Infrastructure Status
echo "📋 Checking Infrastructure Status..."
aws ec2 describe-instances \
  --filters "Name=tag:Environment,Values=$ENV" "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].{ID:InstanceId,IP:PublicIpAddress,State:State.Name}' \
  --output table

# Test RDS Status
echo "🗄️ Checking Database Status..."
aws rds describe-db-instances \
  --db-instance-identifier health-app-shared-db \
  --query 'DBInstances[0].{Status:DBInstanceStatus,Endpoint:Endpoint.Address}' \
  --output table

# Get Cluster IPs
DEV_IP=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=health-app-lower-dev" "Name=instance-state-name,Values=running" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)

TEST_IP=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=health-app-lower-test" "Name=instance-state-name,Values=running" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)

echo "🎯 Cluster IPs:"
echo "  Dev:  $DEV_IP"
echo "  Test: $TEST_IP"

# Test K3s Connectivity using Parameter Store
echo "🔗 Testing K3s Connectivity..."
echo "🧪 Testing Lower Environment Clusters..."

# Test Dev Environment
echo "Testing Dev Environment..."
if ./scripts/get-kubeconfig-from-parameter-store.sh dev /tmp/kubeconfig-dev.yaml; then
    export KUBECONFIG=/tmp/kubeconfig-dev.yaml
    if timeout 30 kubectl get nodes --request-timeout=20s > /dev/null 2>&1; then
        echo "✅ Dev cluster connection successful"
        kubectl get nodes
    else
        echo "❌ Dev cluster connection failed"
    fi
else
    echo "❌ Dev cluster connection failed"
fi

# Test Test Environment
echo "Testing Test Environment..."
if ./scripts/get-kubeconfig-from-parameter-store.sh test /tmp/kubeconfig-test.yaml; then
    export KUBECONFIG=/tmp/kubeconfig-test.yaml
    if timeout 30 kubectl get nodes --request-timeout=20s > /dev/null 2>&1; then
        echo "✅ Test cluster connection successful"
        kubectl get nodes
    else
        echo "❌ Test cluster connection failed"
    fi
else
    echo "❌ Test cluster connection failed"
fi

echo "🎉 Lower Infrastructure Test Complete!"
echo ""
echo "Next Steps:"
echo "1. Add kubeconfigs to GitHub Secrets:"
echo "   - KUBECONFIG_DEV: $(base64 -w 0 /tmp/kubeconfig-dev.yaml 2>/dev/null || echo 'Generate manually')"
echo "   - KUBECONFIG_TEST: $(base64 -w 0 /tmp/kubeconfig-test.yaml 2>/dev/null || echo 'Generate manually')"
echo "2. Run deployment workflow with environment: dev or test"
echo "3. Test application endpoints"