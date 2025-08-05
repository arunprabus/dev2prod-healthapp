#!/bin/bash

echo "🔍 Identifying safe VPCs to delete..."

# Get all non-default VPCs with details
aws ec2 describe-vpcs --query 'Vpcs[?IsDefault==`false`].[VpcId,Tags[?Key==`Name`].Value|[0],State,CidrBlock]' --output table

echo ""
echo "🔍 Checking which VPCs have resources..."

# Check each VPC for resources
for vpc_id in $(aws ec2 describe-vpcs --query 'Vpcs[?IsDefault==`false`].VpcId' --output text); do
    echo "--- VPC: $vpc_id ---"
    
    # Check for EC2 instances
    instances=$(aws ec2 describe-instances --filters "Name=vpc-id,Values=$vpc_id" --query 'length(Reservations[].Instances[])')
    echo "  EC2 instances: $instances"
    
    # Check for RDS instances
    rds=$(aws rds describe-db-instances --query "length(DBInstances[?DBSubnetGroup.VpcId=='$vpc_id'])" 2>/dev/null || echo "0")
    echo "  RDS instances: $rds"
    
    # Check for subnets
    subnets=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$vpc_id" --query 'length(Subnets[])')
    echo "  Subnets: $subnets"
    
    # Check for internet gateways
    igws=$(aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=$vpc_id" --query 'length(InternetGateways[])')
    echo "  Internet Gateways: $igws"
    
    # Get VPC name
    vpc_name=$(aws ec2 describe-vpcs --vpc-ids $vpc_id --query 'Vpcs[0].Tags[?Key==`Name`].Value|[0]' --output text 2>/dev/null || echo "unnamed")
    
    total_resources=$((instances + rds + subnets + igws))
    
    if [ "$total_resources" -eq 0 ] || [ "$total_resources" -eq 1 ]; then
        echo "  ✅ SAFE TO DELETE: $vpc_id ($vpc_name) - minimal resources"
        echo "     Command: aws ec2 delete-vpc --vpc-id $vpc_id"
    else
        echo "  ⚠️  KEEP: $vpc_id ($vpc_name) - has $total_resources resources"
    fi
    echo ""
done

echo "🎯 Quick delete commands for empty VPCs:"
for vpc_id in $(aws ec2 describe-vpcs --query 'Vpcs[?IsDefault==`false`].VpcId' --output text); do
    instances=$(aws ec2 describe-instances --filters "Name=vpc-id,Values=$vpc_id" --query 'length(Reservations[].Instances[])')
    rds=$(aws rds describe-db-instances --query "length(DBInstances[?DBSubnetGroup.VpcId=='$vpc_id'])" 2>/dev/null || echo "0")
    total=$((instances + rds))
    
    if [ "$total" -eq 0 ]; then
        echo "aws ec2 delete-vpc --vpc-id $vpc_id"
    fi
done