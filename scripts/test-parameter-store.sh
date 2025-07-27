#!/bin/bash

# Test Parameter Store integration
ENVIRONMENT=${1:-dev}
REGION="ap-south-1"

echo "🧪 Testing Parameter Store for environment: $ENVIRONMENT"

# Test AWS CLI access to parameters
echo "📋 Listing parameters..."
aws ssm get-parameters-by-path \
  --path "/$ENVIRONMENT/health-app/" \
  --region $REGION \
  --query 'Parameters[*].[Name,Value]' \
  --output table

# Test specific parameter retrieval
echo "🔍 Testing specific parameter retrieval..."
aws ssm get-parameter \
  --name "/$ENVIRONMENT/health-app/database/host" \
  --region $REGION \
  --query 'Parameter.Value' \
  --output text

# Test encrypted parameter
echo "🔐 Testing encrypted parameter..."
aws ssm get-parameter \
  --name "/$ENVIRONMENT/health-app/database/password" \
  --with-decryption \
  --region $REGION \
  --query 'Parameter.Value' \
  --output text

echo "✅ Parameter Store test complete!"