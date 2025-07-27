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

# Test K3s Connectivity
echo "🔗 Testing K3s Connectivity..."
if [ "$DEV_IP" != "None" ]; then
  echo "Testing Dev cluster..."
  ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no ubuntu@$DEV_IP "sudo k3s kubectl get nodes" || echo "❌ Dev cluster unreachable"
fi

if [ "$TEST_IP" != "None" ]; then
  echo "Testing Test cluster..."
  ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no ubuntu@$TEST_IP "sudo k3s kubectl get nodes" || echo "❌ Test cluster unreachable"
fi

# Generate Kubeconfigs
echo "🔑 Generating Kubeconfigs..."
if [ "$DEV_IP" != "None" ]; then
  ./scripts/setup-kubeconfig.sh dev $DEV_IP > /tmp/kubeconfig-dev.yaml
  echo "✅ Dev kubeconfig generated"
fi

if [ "$TEST_IP" != "None" ]; then
  ./scripts/setup-kubeconfig.sh test $TEST_IP > /tmp/kubeconfig-test.yaml
  echo "✅ Test kubeconfig generated"
fi

echo "🎉 Lower Infrastructure Test Complete!"
echo ""
echo "Next Steps:"
echo "1. Add kubeconfigs to GitHub Secrets:"
echo "   - KUBECONFIG_DEV: $(base64 -w 0 /tmp/kubeconfig-dev.yaml 2>/dev/null || echo 'Generate manually')"
echo "   - KUBECONFIG_TEST: $(base64 -w 0 /tmp/kubeconfig-test.yaml 2>/dev/null || echo 'Generate manually')"
echo "2. Run deployment workflow with environment: dev or test"
echo "3. Test application endpoints"