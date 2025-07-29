#!/bin/bash

# Fix Parameter Store values with correct cluster IPs
echo "🔧 Fixing Parameter Store values..."

# From your terraform output:
DEV_IP="13.232.75.155"
TEST_IP="13.127.158.59"

echo "📝 Updating dev cluster Parameter Store..."
aws ssm put-parameter \
  --name "/dev/health-app/kubeconfig/server" \
  --value "https://$DEV_IP:6443" \
  --type "String" \
  --overwrite \
  --region ap-south-1

echo "📝 Updating test cluster Parameter Store..."
aws ssm put-parameter \
  --name "/test/health-app/kubeconfig/server" \
  --value "https://$TEST_IP:6443" \
  --type "String" \
  --overwrite \
  --region ap-south-1

echo "✅ Parameter Store values updated"

# Verify the changes
echo "🔍 Verifying Parameter Store values..."
echo "Dev server:"
aws ssm get-parameter --name "/dev/health-app/kubeconfig/server" --query 'Parameter.Value' --output text --region ap-south-1

echo "Test server:"
aws ssm get-parameter --name "/test/health-app/kubeconfig/server" --query 'Parameter.Value' --output text --region ap-south-1

echo "✅ Fix complete!"