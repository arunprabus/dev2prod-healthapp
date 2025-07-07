#!/bin/bash

# Quick AWS Resource Check Script
REGION=${1:-"ap-south-1"}

echo "🔍 Checking AWS Resources in $REGION"
echo "======================================"

echo "🖥️  EC2 Instances:"
aws ec2 describe-instances \
    --region $REGION \
    --query "Reservations[].Instances[?State.Name!='terminated'].[InstanceId,State.Name,Tags[?Key=='Name'].Value|[0]]" \
    --output table 2>/dev/null || echo "None found"

echo ""
echo "🗄️  RDS Instances:"
aws rds describe-db-instances \
    --region $REGION \
    --query "DBInstances[].[DBInstanceIdentifier,DBInstanceStatus]" \
    --output table 2>/dev/null || echo "None found"

echo ""
echo "🛡️  Security Groups (non-default):"
aws ec2 describe-security-groups \
    --region $REGION \
    --query "SecurityGroups[?GroupName!='default'].[GroupId,GroupName]" \
    --output table 2>/dev/null || echo "None found"

echo ""
echo "🌐 Subnets (non-default):"
aws ec2 describe-subnets \
    --region $REGION \
    --filters "Name=tag:Project,Values=Learning" \
    --query "Subnets[].[SubnetId,CidrBlock,Tags[?Key=='Name'].Value|[0]]" \
    --output table 2>/dev/null || echo "None found"

echo ""
echo "🔑 Key Pairs:"
aws ec2 describe-key-pairs \
    --region $REGION \
    --query "KeyPairs[?contains(KeyName,'dev-') || contains(KeyName,'test-') || contains(KeyName,'prod-') || contains(KeyName,'monitoring-')].[KeyName]" \
    --output table 2>/dev/null || echo "None found"

echo ""
echo "💰 Estimated Monthly Cost: Check AWS Billing Console"