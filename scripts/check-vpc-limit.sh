#!/bin/bash

# Quick VPC limit checker and cleaner

echo "🔍 Checking AWS VPC usage..."

# List all non-default VPCs
echo "Current VPCs:"
aws ec2 describe-vpcs --query 'Vpcs[?IsDefault==`false`].[VpcId,Tags[?Key==`Name`].Value|[0],State,CidrBlock]' --output table

# Count VPCs
VPC_COUNT=$(aws ec2 describe-vpcs --query 'length(Vpcs[?IsDefault==`false`])' --output text)
echo "Non-default VPC count: $VPC_COUNT/5"

if [ "$VPC_COUNT" -ge 5 ]; then
    echo "❌ VPC limit reached. Need to delete unused VPCs."
    echo ""
    echo "🗑️  To delete a VPC:"
    echo "1. aws ec2 describe-vpcs --vpc-ids vpc-xxxxxxxxx"
    echo "2. aws ec2 delete-vpc --vpc-id vpc-xxxxxxxxx"
    echo ""
    echo "Or delete all health-app VPCs:"
    aws ec2 describe-vpcs --filters "Name=tag:Project,Values=health-app" --query 'Vpcs[].VpcId' --output text | xargs -n1 -I {} aws ec2 delete-vpc --vpc-id {}
else
    echo "✅ VPC limit OK. You can create $((5 - VPC_COUNT)) more VPCs."
fi