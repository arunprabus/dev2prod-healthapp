#!/bin/bash

# Single Region VPC Cleanup
# Usage: ./single-region-cleanup.sh <region> [dry-run]

set -e

REGION=${1:-"us-east-1"}
DRY_RUN=${2:-"true"}
ACTIVE_REGION="ap-south-1"

if [[ "$REGION" == "$ACTIVE_REGION" ]]; then
    echo "❌ Cannot cleanup active region: $ACTIVE_REGION"
    exit 1
fi

echo "🧹 Cleaning up region: $REGION"
echo "Dry run: $DRY_RUN"

# Get custom VPCs
vpcs=$(aws ec2 describe-vpcs --region "$REGION" --filters "Name=isDefault,Values=false" --query 'Vpcs[].VpcId' --output text 2>/dev/null || echo "")

if [[ -z "$vpcs" ]]; then
    echo "✅ No custom VPCs found in $REGION"
    exit 0
fi

for vpc in $vpcs; do
    echo "🔍 Checking VPC: $vpc"
    
    # Check usage
    instances=$(aws ec2 describe-instances --region "$REGION" --filters "Name=vpc-id,Values=$vpc" "Name=instance-state-name,Values=running,stopped" --query 'length(Reservations[].Instances[])' 2>/dev/null || echo "0")
    nat_gws=$(aws ec2 describe-nat-gateways --region "$REGION" --filter "Name=vpc-id,Values=$vpc" --query 'length(NatGateways[?State==`available`])' 2>/dev/null || echo "0")
    
    if [[ "$instances" -gt 0 || "$nat_gws" -gt 0 ]]; then
        echo "  ✅ VPC in use (instances: $instances, NAT GWs: $nat_gws) - skipping"
        continue
    fi
    
    echo "  ❌ VPC appears unused - cleaning up"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "    [DRY RUN] Would delete VPC $vpc and related resources"
        continue
    fi
    
    # Actual cleanup
    echo "    Deleting subnets..."
    subnets=$(aws ec2 describe-subnets --region "$REGION" --filters "Name=vpc-id,Values=$vpc" --query 'Subnets[].SubnetId' --output text 2>/dev/null || echo "")
    for subnet in $subnets; do
        aws ec2 delete-subnet --region "$REGION" --subnet-id "$subnet" 2>/dev/null || true
    done
    
    echo "    Deleting route tables..."
    route_tables=$(aws ec2 describe-route-tables --region "$REGION" --filters "Name=vpc-id,Values=$vpc" --query 'RouteTables[?Associations[0].Main!=`true`].RouteTableId' --output text 2>/dev/null || echo "")
    for rt in $route_tables; do
        aws ec2 delete-route-table --region "$REGION" --route-table-id "$rt" 2>/dev/null || true
    done
    
    echo "    Deleting internet gateway..."
    igw=$(aws ec2 describe-internet-gateways --region "$REGION" --filters "Name=attachment.vpc-id,Values=$vpc" --query 'InternetGateways[].InternetGatewayId' --output text 2>/dev/null || echo "")
    if [[ -n "$igw" ]]; then
        aws ec2 detach-internet-gateway --region "$REGION" --internet-gateway-id "$igw" --vpc-id "$vpc" 2>/dev/null || true
        aws ec2 delete-internet-gateway --region "$REGION" --internet-gateway-id "$igw" 2>/dev/null || true
    fi
    
    echo "    Deleting security groups..."
    security_groups=$(aws ec2 describe-security-groups --region "$REGION" --filters "Name=vpc-id,Values=$vpc" --query 'SecurityGroups[?GroupName!=`default`].GroupId' --output text 2>/dev/null || echo "")
    for sg in $security_groups; do
        aws ec2 delete-security-group --region "$REGION" --group-id "$sg" 2>/dev/null || true
    done
    
    echo "    Deleting VPC..."
    aws ec2 delete-vpc --region "$REGION" --vpc-id "$vpc" 2>/dev/null || true
    
    echo "  ✅ VPC $vpc cleanup completed"
done

echo "🎉 Region $REGION cleanup completed"