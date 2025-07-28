#!/bin/bash

# Quick fix for kubeconfig issues
set -e

echo "🔍 Checking cluster status..."

# Check dev cluster
DEV_IP=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=health-app-lower-dev-k3s-node-v2" "Name=instance-state-name,Values=running" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' --output text 2>/dev/null || echo "None")

if [ "$DEV_IP" = "None" ]; then
  DEV_IP="13.233.89.253"  # Hardcoded from console
fi

# Check test cluster  
TEST_IP=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=health-app-lower-test-k3s-node-v2" "Name=instance-state-name,Values=running" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' --output text 2>/dev/null || echo "None")

if [ "$TEST_IP" = "None" ]; then
  TEST_IP="3.111.55.233"   # Hardcoded from console
fi

echo "Dev IP: $DEV_IP"
echo "Test IP: $TEST_IP"

# Fix dev cluster
if [ "$DEV_IP" != "None" ]; then
  echo "🔧 Fixing dev cluster..."
  
  # Get token directly from cluster
  TOKEN=$(ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no ubuntu@$DEV_IP \
    "sudo k3s kubectl create token gha-deployer -n gha-access --duration=24h 2>/dev/null || \
     (sudo k3s kubectl create namespace gha-access && \
      sudo k3s kubectl create serviceaccount gha-deployer -n gha-access && \
      sudo k3s kubectl create role gha-role --verb=get,list,watch,create,update,patch,delete --resource=pods,services,deployments,namespaces -n gha-access && \
      sudo k3s kubectl create rolebinding gha-rolebinding --role=gha-role --serviceaccount=gha-access:gha-deployer -n gha-access && \
      sudo k3s kubectl create token gha-deployer -n gha-access --duration=24h)" 2>/dev/null)
  
  if [ -n "$TOKEN" ]; then
    # Store in Parameter Store
    aws ssm put-parameter --name "/dev/health-app/kubeconfig/server" --value "https://$DEV_IP:6443" --type "String" --overwrite --region ap-south-1
    aws ssm put-parameter --name "/dev/health-app/kubeconfig/token" --value "$TOKEN" --type "SecureString" --overwrite --region ap-south-1
    aws ssm put-parameter --name "/dev/health-app/kubeconfig/cluster-name" --value "k3s-cluster" --type "String" --overwrite --region ap-south-1
    echo "✅ Dev cluster fixed"
  fi
fi

# Fix test cluster
if [ "$TEST_IP" != "None" ]; then
  echo "🔧 Fixing test cluster..."
  
  TOKEN=$(ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no ubuntu@$TEST_IP \
    "sudo k3s kubectl create token gha-deployer -n gha-access --duration=24h 2>/dev/null || \
     (sudo k3s kubectl create namespace gha-access && \
      sudo k3s kubectl create serviceaccount gha-deployer -n gha-access && \
      sudo k3s kubectl create role gha-role --verb=get,list,watch,create,update,patch,delete --resource=pods,services,deployments,namespaces -n gha-access && \
      sudo k3s kubectl create rolebinding gha-rolebinding --role=gha-role --serviceaccount=gha-access:gha-deployer -n gha-access && \
      sudo k3s kubectl create token gha-deployer -n gha-access --duration=24h)" 2>/dev/null)
  
  if [ -n "$TOKEN" ]; then
    aws ssm put-parameter --name "/test/health-app/kubeconfig/server" --value "https://$TEST_IP:6443" --type "String" --overwrite --region ap-south-1
    aws ssm put-parameter --name "/test/health-app/kubeconfig/token" --value "$TOKEN" --type "SecureString" --overwrite --region ap-south-1
    aws ssm put-parameter --name "/test/health-app/kubeconfig/cluster-name" --value "k3s-cluster" --type "String" --overwrite --region ap-south-1
    echo "✅ Test cluster fixed"
  fi
fi

echo "🧪 Testing connections..."
if [ -f "./scripts/test-lower-deployment.sh" ]; then
  ./scripts/test-lower-deployment.sh
elif [ -f "./test-lower-deployment.sh" ]; then
  ./test-lower-deployment.sh
else
  echo "✅ Parameter Store setup complete! Test manually with:"
  echo "./scripts/get-kubeconfig-from-parameter-store.sh dev"
  echo "./scripts/get-kubeconfig-from-parameter-store.sh test"
fi