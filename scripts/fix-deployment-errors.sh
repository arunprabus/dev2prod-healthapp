#!/bin/bash

# Quick fix for deployment errors
# Usage: ./fix-deployment-errors.sh

echo "🔧 Fixing deployment errors..."

# 1. Remove any existing failed resources
echo "Cleaning up any failed resources..."
aws iam delete-role-policy --role-name health-app-runner-role-lower --policy-name health-app-runner-policy-lower 2>/dev/null || true
aws iam remove-role-from-instance-profile --instance-profile-name health-app-runner-profile-lower --role-name health-app-runner-role-lower 2>/dev/null || true
aws iam delete-instance-profile --instance-profile-name health-app-runner-profile-lower 2>/dev/null || true
aws iam delete-role --role-name health-app-runner-role-lower 2>/dev/null || true

# 2. Check if key pair exists
if ! aws ec2 describe-key-pairs --key-names health-app-lower-key >/dev/null 2>&1; then
    echo "❌ Key pair health-app-lower-key doesn't exist"
    echo "💡 You need to run the infrastructure deployment first to create the key pair"
    exit 1
fi

echo "✅ Key pair exists"

# 3. Validate terraform configuration
cd infra
terraform validate
if [ $? -eq 0 ]; then
    echo "✅ Terraform configuration is valid"
else
    echo "❌ Terraform configuration has errors"
    exit 1
fi

echo "🎉 Ready for deployment!"
echo ""
echo "Next steps:"
echo "1. Run: GitHub Actions → Core Infrastructure → deploy → lower"
echo "2. Wait for completion"
echo "3. Run: GitHub Actions → Scale and Deploy"