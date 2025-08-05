#!/bin/bash

# AWS Resource Cleanup Script
# Removes duplicate/conflicting resources to allow fresh deployment

set -e

echo "🧹 Cleaning up AWS resources..."

# 1. Remove duplicate key pairs
echo "Removing duplicate key pairs..."
aws ec2 delete-key-pair --key-name "health-app-lower-key" --region ap-south-1 || true
aws ec2 delete-key-pair --key-name "health-app-higher-key" --region ap-south-1 || true
aws ec2 delete-key-pair --key-name "health-app-monitoring-key" --region ap-south-1 || true

# 2. Remove duplicate IAM roles
echo "Removing duplicate IAM roles..."
aws iam detach-role-policy --role-name "health-app-lower-k3s-role" --policy-arn "arn:aws:iam::aws:policy/AmazonEC2FullAccess" || true
aws iam detach-role-policy --role-name "health-app-lower-k3s-role" --policy-arn "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore" || true
aws iam remove-role-from-instance-profile --instance-profile-name "health-app-lower-k3s-profile" --role-name "health-app-lower-k3s-role" || true
aws iam delete-instance-profile --instance-profile-name "health-app-lower-k3s-profile" || true
aws iam delete-role --role-name "health-app-lower-k3s-role" || true

# Similar for other environments
aws iam detach-role-policy --role-name "health-app-higher-k3s-role" --policy-arn "arn:aws:iam::aws:policy/AmazonEC2FullAccess" || true
aws iam detach-role-policy --role-name "health-app-higher-k3s-role" --policy-arn "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore" || true
aws iam remove-role-from-instance-profile --instance-profile-name "health-app-higher-k3s-profile" --role-name "health-app-higher-k3s-role" || true
aws iam delete-instance-profile --instance-profile-name "health-app-higher-k3s-profile" || true
aws iam delete-role --role-name "health-app-higher-k3s-role" || true

aws iam detach-role-policy --role-name "health-app-monitoring-k3s-role" --policy-arn "arn:aws:iam::aws:policy/AmazonEC2FullAccess" || true
aws iam detach-role-policy --role-name "health-app-monitoring-k3s-role" --policy-arn "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore" || true
aws iam remove-role-from-instance-profile --instance-profile-name "health-app-monitoring-k3s-profile" --role-name "health-app-monitoring-k3s-role" || true
aws iam delete-instance-profile --instance-profile-name "health-app-monitoring-k3s-profile" || true
aws iam delete-role --role-name "health-app-monitoring-k3s-role" || true

# 3. Check VPC limit and list existing VPCs
echo "Checking VPC usage..."
aws ec2 describe-vpcs --query 'Vpcs[?IsDefault==`false`].[VpcId,Tags[?Key==`Name`].Value|[0],State]' --output table

echo "Current VPC count:"
aws ec2 describe-vpcs --query 'length(Vpcs[?IsDefault==`false`])'

echo "VPC Limit (default is 5):"
aws ec2 describe-account-attributes --attribute-names vpc-max-security-groups-per-vpc --query 'AccountAttributes[0].AttributeValues[0].AttributeValue'

# 4. Suggest VPC cleanup if needed
VPC_COUNT=$(aws ec2 describe-vpcs --query 'length(Vpcs[?IsDefault==`false`])' --output text)
if [ "$VPC_COUNT" -ge 5 ]; then
    echo "⚠️  You have $VPC_COUNT non-default VPCs. AWS limit is 5."
    echo "🗑️  Delete unused VPCs manually or run:"
    echo "   aws ec2 delete-vpc --vpc-id vpc-xxxxxxxxx"
fi

echo "✅ Cleanup completed. You can now run terraform apply."