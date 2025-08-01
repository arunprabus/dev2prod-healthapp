#!/bin/bash
set -e

echo "🔍 Validating GitHub Actions workflow and infrastructure..."

# Check required secrets
echo "📋 Checking required GitHub secrets..."
REQUIRED_SECRETS=(
    "AWS_ACCESS_KEY_ID"
    "AWS_SECRET_ACCESS_KEY" 
    "TF_STATE_BUCKET"
    "SSH_PUBLIC_KEY"
    "SSH_PRIVATE_KEY"
    "REPO_PAT"
)

for secret in "${REQUIRED_SECRETS[@]}"; do
    echo "  - $secret: Required"
done

# Check AWS permissions
echo "🔐 Checking AWS permissions..."
aws sts get-caller-identity > /dev/null && echo "✅ AWS credentials valid" || echo "❌ AWS credentials invalid"

# Check Terraform state bucket
echo "🪣 Checking Terraform state bucket..."
if aws s3 ls "s3://${TF_STATE_BUCKET:-health-app-terraform-state}" > /dev/null 2>&1; then
    echo "✅ Terraform state bucket accessible"
else
    echo "❌ Terraform state bucket not accessible"
fi

# Check instance tags and naming
echo "🏷️ Checking instance naming conventions..."
EXPECTED_TAGS=(
    "health-app-dev-k3s"
    "health-app-test-k3s" 
    "health-app-runner-lower"
)

for tag in "${EXPECTED_TAGS[@]}"; do
    INSTANCES=$(aws ec2 describe-instances \
        --filters "Name=tag:Name,Values=$tag" "Name=instance-state-name,Values=running" \
        --query 'Reservations[].Instances[].InstanceId' --output text)
    
    if [ -n "$INSTANCES" ] && [ "$INSTANCES" != "None" ]; then
        echo "✅ Found instances with tag: $tag"
    else
        echo "⚠️ No running instances found with tag: $tag"
    fi
done

# Check SSM agent status
echo "🔧 Checking SSM agent status on instances..."
aws ssm describe-instance-information \
    --query 'InstanceInformationList[?PingStatus==`Online`].[InstanceId,Name,PingStatus]' \
    --output table

# Check security groups
echo "🛡️ Checking security group configuration..."
aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=health-app-*" \
    --query 'SecurityGroups[].{Name:GroupName,ID:GroupId,Rules:length(IpPermissions)}' \
    --output table

echo "✅ Workflow validation completed"