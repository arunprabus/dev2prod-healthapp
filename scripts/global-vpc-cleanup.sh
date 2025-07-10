#!/bin/bash

# Global VPC Cleanup Script
# Removes default VPCs from unused regions to free up resource limits

set -e

ACTIVE_REGION="ap-south-1"
DRY_RUN=${1:-"true"}

# All AWS regions
REGIONS=(
    "us-east-1" "us-east-2" "us-west-1" "us-west-2"
    "ap-northeast-1" "ap-northeast-2" "ap-northeast-3"
    "ap-southeast-1" "ap-southeast-2" "ap-south-1"
    "eu-west-1" "eu-west-2" "eu-west-3" "eu-central-1" "eu-north-1"
    "ca-central-1" "sa-east-1"
)

echo "🌍 Global VPC Cleanup"
echo "Active region: $ACTIVE_REGION"
echo "Dry run: $DRY_RUN"
echo ""

cleanup_region() {
    local region=$1
    
    if [[ "$region" == "$ACTIVE_REGION" ]]; then
        echo "⏭️  Skipping active region: $region"
        return
    fi
    
    echo "🔍 Checking region: $region"
    
    # Get default VPC
    local vpc_id=$(aws ec2 describe-vpcs --region "$region" --filters "Name=isDefault,Values=true" --query 'Vpcs[0].VpcId' --output text 2>/dev/null || echo "None")
    
    if [[ "$vpc_id" == "None" || "$vpc_id" == "null" ]]; then
        echo "  ✅ No default VPC found"
        return
    fi
    
    echo "  📍 Found default VPC: $vpc_id"
    
    # Check for running instances
    local instances=$(aws ec2 describe-instances --region "$region" --filters "Name=vpc-id,Values=$vpc_id" "Name=instance-state-name,Values=running,stopped" --query 'length(Reservations[].Instances[])' --output text 2>/dev/null || echo "0")
    
    if [[ "$instances" -gt 0 ]]; then
        echo "  ⚠️  VPC has $instances instances - skipping"
        return
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "  [DRY RUN] Would delete default VPC and resources"
        return
    fi
    
    echo "  🧹 Cleaning up default VPC resources..."
    
    # Delete subnets
    local subnets=$(aws ec2 describe-subnets --region "$region" --filters "Name=vpc-id,Values=$vpc_id" --query 'Subnets[].SubnetId' --output text 2>/dev/null || echo "")
    for subnet in $subnets; do
        echo "    Deleting subnet: $subnet"
        aws ec2 delete-subnet --region "$region" --subnet-id "$subnet" 2>/dev/null || true
    done
    
    # Delete internet gateway
    local igw=$(aws ec2 describe-internet-gateways --region "$region" --filters "Name=attachment.vpc-id,Values=$vpc_id" --query 'InternetGateways[0].InternetGatewayId' --output text 2>/dev/null || echo "None")
    if [[ "$igw" != "None" && "$igw" != "null" ]]; then
        echo "    Detaching IGW: $igw"
        aws ec2 detach-internet-gateway --region "$region" --internet-gateway-id "$igw" --vpc-id "$vpc_id" 2>/dev/null || true
        echo "    Deleting IGW: $igw"
        aws ec2 delete-internet-gateway --region "$region" --internet-gateway-id "$igw" 2>/dev/null || true
    fi
    
    # Delete security groups (except default)
    local security_groups=$(aws ec2 describe-security-groups --region "$region" --filters "Name=vpc-id,Values=$vpc_id" --query 'SecurityGroups[?GroupName!=`default`].GroupId' --output text 2>/dev/null || echo "")
    for sg in $security_groups; do
        echo "    Deleting security group: $sg"
        aws ec2 delete-security-group --region "$region" --group-id "$sg" 2>/dev/null || true
    done
    
    # Delete route tables (except main)
    local route_tables=$(aws ec2 describe-route-tables --region "$region" --filters "Name=vpc-id,Values=$vpc_id" --query 'RouteTables[?Associations[0].Main!=`true`].RouteTableId' --output text 2>/dev/null || echo "")
    for rt in $route_tables; do
        echo "    Deleting route table: $rt"
        aws ec2 delete-route-table --region "$region" --route-table-id "$rt" 2>/dev/null || true
    done
    
    # Delete VPC
    echo "    Deleting VPC: $vpc_id"
    aws ec2 delete-vpc --region "$region" --vpc-id "$vpc_id" 2>/dev/null || true
    
    echo "  ✅ Region $region cleanup completed"
}

# Process all regions
for region in "${REGIONS[@]}"; do
    cleanup_region "$region"
    echo ""
done

echo "🎉 Global cleanup completed!"

if [[ "$DRY_RUN" == "true" ]]; then
    echo ""
    echo "💡 This was a DRY RUN. To execute cleanup:"
    echo "   ./scripts/global-vpc-cleanup.sh false"
fi