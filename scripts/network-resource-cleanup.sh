#!/bin/bash

# Network Resource Cleanup Script
# Removes network interfaces, route tables, and other networking resources

set -e

ACTIVE_REGION="ap-south-1"
DRY_RUN=${1:-"true"}

REGIONS=(
    "us-east-1" "us-east-2" "us-west-1" "us-west-2"
    "ap-northeast-1" "ap-northeast-2" "ap-northeast-3"
    "ap-southeast-1" "ap-southeast-2"
    "eu-west-1" "eu-west-2" "eu-west-3" "eu-central-1" "eu-north-1"
    "ca-central-1" "sa-east-1"
)

echo "🌐 Network Resource Cleanup"
echo "Active region: $ACTIVE_REGION (will be skipped)"
echo "Dry run: $DRY_RUN"
echo ""

cleanup_network_resources() {
    local region=$1
    
    if [[ "$region" == "$ACTIVE_REGION" ]]; then
        echo "⏭️  Skipping active region: $region"
        return
    fi
    
    echo "🔍 Cleaning region: $region"
    
    if [[ "$DRY_RUN" == "false" ]]; then
        # Delete available network interfaces
        local enis=$(aws ec2 describe-network-interfaces --region "$region" --filters "Name=status,Values=available" --query 'NetworkInterfaces[].NetworkInterfaceId' --output text 2>/dev/null || echo "")
        for eni in $enis; do
            echo "  🔌 Deleting network interface: $eni"
            aws ec2 delete-network-interface --region "$region" --network-interface-id "$eni" 2>/dev/null || true
        done
        
        # Release unassociated Elastic IPs
        local eips=$(aws ec2 describe-addresses --region "$region" --query 'Addresses[?AssociationId==null].AllocationId' --output text 2>/dev/null || echo "")
        for eip in $eips; do
            echo "  🌐 Releasing Elastic IP: $eip"
            aws ec2 release-address --region "$region" --allocation-id "$eip" 2>/dev/null || true
        done
        
        # Delete custom route tables
        local route_tables=$(aws ec2 describe-route-tables --region "$region" --query 'RouteTables[?Associations[0].Main!=`true`].RouteTableId' --output text 2>/dev/null || echo "")
        for rt in $route_tables; do
            echo "  🛣️  Deleting route table: $rt"
            aws ec2 delete-route-table --region "$region" --route-table-id "$rt" 2>/dev/null || true
        done
        
        # Delete custom security groups
        local security_groups=$(aws ec2 describe-security-groups --region "$region" --query 'SecurityGroups[?GroupName!=`default`].GroupId' --output text 2>/dev/null || echo "")
        for sg in $security_groups; do
            echo "  🛡️  Deleting security group: $sg"
            aws ec2 delete-security-group --region "$region" --group-id "$sg" 2>/dev/null || true
        done
        
        echo "  ✅ Region $region cleanup completed"
    else
        echo "  [DRY RUN] Would clean network resources in $region"
    fi
}

# Process all regions except active
for region in "${REGIONS[@]}"; do
    cleanup_network_resources "$region"
done

echo ""
echo "🎉 Network cleanup completed!"

if [[ "$DRY_RUN" == "true" ]]; then
    echo ""
    echo "💡 To execute cleanup:"
    echo "   bash scripts/network-resource-cleanup.sh false"
fi