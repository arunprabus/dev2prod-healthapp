#!/bin/bash

# Quick VPC Usage Check
# Fast check for unused VPCs across regions

ACTIVE_REGION="ap-south-1"

echo "🔍 Quick VPC Usage Check"
echo "Active Region: $ACTIVE_REGION"
echo "=========================="

for region in $(aws ec2 describe-regions --query 'Regions[].RegionName' --output text); do
    if [[ "$region" == "$ACTIVE_REGION" ]]; then
        continue
    fi
    
    # Check for custom VPCs
    custom_vpcs=$(aws ec2 describe-vpcs --region "$region" --filters "Name=isDefault,Values=false" --query 'Vpcs[].VpcId' --output text)
    
    if [[ -n "$custom_vpcs" ]]; then
        echo "❌ $region: Custom VPCs found"
        for vpc in $custom_vpcs; do
            # Quick usage check
            instances=$(aws ec2 describe-instances --region "$region" --filters "Name=vpc-id,Values=$vpc" "Name=instance-state-name,Values=running,stopped" --query 'length(Reservations[].Instances[])')
            nat_gws=$(aws ec2 describe-nat-gateways --region "$region" --filter "Name=vpc-id,Values=$vpc" --query 'length(NatGateways[?State==`available`])')
            
            if [[ "$instances" -eq 0 && "$nat_gws" -eq 0 ]]; then
                echo "  🗑️  $vpc - UNUSED (safe to delete)"
            else
                echo "  ✅ $vpc - IN USE (instances: $instances, NAT GWs: $nat_gws)"
            fi
        done
    else
        echo "✅ $region: No custom VPCs"
    fi
done

echo ""
echo "💡 To cleanup unused VPCs, run:"
echo "   DRY_RUN=true ./scripts/aws-resource-cleanup.sh"