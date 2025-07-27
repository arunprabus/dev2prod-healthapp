#!/bin/bash

# Fix SSM Parameter Store permissions
USER_NAME="dev2prod_user"
POLICY_NAME="HealthAppSSMParameterPolicy"

echo "🔧 Adding SSM Parameter Store permissions..."

# Create the policy
aws iam create-policy \
  --policy-name $POLICY_NAME \
  --policy-document file://policies/ssm-parameter-policy.json \
  --description "SSM Parameter Store access for Health App"

# Get the policy ARN
POLICY_ARN=$(aws iam list-policies --query "Policies[?PolicyName=='$POLICY_NAME'].Arn" --output text)

# Attach the policy to the user
aws iam attach-user-policy \
  --user-name $USER_NAME \
  --policy-arn $POLICY_ARN

echo "✅ SSM permissions added successfully!"
echo "Policy ARN: $POLICY_ARN"