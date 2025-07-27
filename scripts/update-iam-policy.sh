#!/bin/bash

USER_NAME="dev2prod_user"
POLICY_NAME="HealthAppPolicy"

echo "🔧 Updating IAM policy with SSM permissions..."

# Get existing policy ARN
POLICY_ARN=$(aws iam list-policies --query "Policies[?PolicyName=='$POLICY_NAME'].Arn" --output text)

if [ -z "$POLICY_ARN" ]; then
  echo "❌ Policy $POLICY_NAME not found. Creating new policy..."
  aws iam create-policy \
    --policy-name $POLICY_NAME \
    --policy-document file://policies/aws-iam-policy.json
  
  POLICY_ARN=$(aws iam list-policies --query "Policies[?PolicyName=='$POLICY_NAME'].Arn" --output text)
  
  aws iam attach-user-policy \
    --user-name $USER_NAME \
    --policy-arn $POLICY_ARN
else
  echo "📝 Updating existing policy..."
  # Create new version
  aws iam create-policy-version \
    --policy-arn $POLICY_ARN \
    --policy-document file://policies/aws-iam-policy.json \
    --set-as-default
fi

echo "✅ IAM policy updated successfully!"
echo "Policy ARN: $POLICY_ARN"