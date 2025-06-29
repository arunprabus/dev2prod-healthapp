#!/bin/bash

# AWS Resource Cleanup Script
# Identifies and optionally deletes unused AWS resources across regions

set -e

# Configuration
ACTIVE_REGION="ap-south-1"
DRY_RUN=${DRY_RUN:-true}
LOG_FILE="cleanup-$(date +%Y%m%d-%H%M%S).log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "$1" | tee -a "$LOG_FILE"
}

get_regions() {
    aws ec2 describe-regions --query 'Regions[].RegionName' --output text
}

check_vpc_usage() {
    local region=$1
    local vpc_id=$2
    
    # Check for instances, NAT gateways, load balancers, etc.
    local instances=$(aws ec2 describe-instances --region "$region" --filters "Name=vpc-id,Values=$vpc_id" "Name=instance-state-name,Values=running,stopped,stopping,pending" --query 'Reservations[].Instances[].InstanceId' --output text)
    local nat_gws=$(aws ec2 describe-nat-gateways --region "$region" --filter "Name=vpc-id,Values=$vpc_id" --query 'NatGateways[?State==`available`].NatGatewayId' --output text)
    local load_balancers=$(aws elbv2 describe-load-balancers --region "$region" --query "LoadBalancers[?VpcId=='$vpc_id'].LoadBalancerArn" --output text 2>/dev/null || echo "")
    
    if [[ -n "$instances" || -n "$nat_gws" || -n "$load_balancers" ]]; then
        return 1  # VPC is in use
    fi
    return 0  # VPC is unused
}

cleanup_vpc() {
    local region=$1
    local vpc_id=$2
    
    log "${YELLOW}Cleaning up VPC $vpc_id in $region${NC}"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "  [DRY RUN] Would delete VPC $vpc_id"
        return
    fi
    
    # Delete subnets
    local subnets=$(aws ec2 describe-subnets --region "$region" --filters "Name=vpc-id,Values=$vpc_id" --query 'Subnets[].SubnetId' --output text)
    for subnet in $subnets; do
        log "  Deleting subnet: $subnet"
        aws ec2 delete-subnet --region "$region" --subnet-id "$subnet" || true
    done
    
    # Delete route tables (except main)
    local route_tables=$(aws ec2 describe-route-tables --region "$region" --filters "Name=vpc-id,Values=$vpc_id" --query 'RouteTables[?Associations[0].Main!=`true`].RouteTableId' --output text)
    for rt in $route_tables; do
        log "  Deleting route table: $rt"
        aws ec2 delete-route-table --region "$region" --route-table-id "$rt" || true
    done
    
    # Delete internet gateway
    local igw=$(aws ec2 describe-internet-gateways --region "$region" --filters "Name=attachment.vpc-id,Values=$vpc_id" --query 'InternetGateways[].InternetGatewayId' --output text)
    if [[ -n "$igw" ]]; then
        log "  Detaching and deleting IGW: $igw"
        aws ec2 detach-internet-gateway --region "$region" --internet-gateway-id "$igw" --vpc-id "$vpc_id" || true
        aws ec2 delete-internet-gateway --region "$region" --internet-gateway-id "$igw" || true
    fi
    
    # Delete security groups (except default)
    local security_groups=$(aws ec2 describe-security-groups --region "$region" --filters "Name=vpc-id,Values=$vpc_id" --query 'SecurityGroups[?GroupName!=`default`].GroupId' --output text)
    for sg in $security_groups; do
        log "  Deleting security group: $sg"
        aws ec2 delete-security-group --region "$region" --group-id "$sg" || true
    done
    
    # Delete VPC
    log "  Deleting VPC: $vpc_id"
    aws ec2 delete-vpc --region "$region" --vpc-id "$vpc_id" || true
}

main() {
    log "${GREEN}🧹 AWS Resource Cleanup Started${NC}"
    log "Active Region: $ACTIVE_REGION"
    log "Dry Run: $DRY_RUN"
    log "Log File: $LOG_FILE"
    
    local total_savings=0
    
    for region in $(get_regions); do
        log "\n${YELLOW}📍 Checking region: $region${NC}"
        
        if [[ "$region" == "$ACTIVE_REGION" ]]; then
            log "  ⏭️  Skipping active region"
            continue
        fi
        
        # Get non-default VPCs
        local vpcs=$(aws ec2 describe-vpcs --region "$region" --filters "Name=isDefault,Values=false" --query 'Vpcs[].VpcId' --output text)
        
        if [[ -z "$vpcs" ]]; then
            log "  ✅ No custom VPCs found"
            continue
        fi
        
        for vpc in $vpcs; do
            log "  🔍 Checking VPC: $vpc"
            
            if check_vpc_usage "$region" "$vpc"; then
                log "    ❌ VPC appears unused - marking for cleanup"
                cleanup_vpc "$region" "$vpc"
                ((total_savings += 5))  # Estimated monthly savings
            else
                log "    ✅ VPC is in use - keeping"
            fi
        done
    done
    
    log "\n${GREEN}✅ Cleanup completed${NC}"
    log "Estimated monthly savings: \$${total_savings}"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "\n${YELLOW}This was a DRY RUN. Set DRY_RUN=false to execute deletions.${NC}"
    fi
}

main "$@"