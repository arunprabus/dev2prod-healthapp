#!/bin/bash

# AWS Resource Audit Script
# Generates detailed report of resources across all regions

set -e

ACTIVE_REGION="ap-south-1"
REPORT_FILE="aws-resource-audit-$(date +%Y%m%d-%H%M%S).json"

log() {
    echo "$1" | tee -a "audit.log"
}

audit_region() {
    local region=$1
    local report="{\"region\":\"$region\","
    
    # VPCs
    local vpcs=$(aws ec2 describe-vpcs --region "$region" --query 'length(Vpcs)')
    local custom_vpcs=$(aws ec2 describe-vpcs --region "$region" --filters "Name=isDefault,Values=false" --query 'length(Vpcs)')
    
    # Internet Gateways
    local igws=$(aws ec2 describe-internet-gateways --region "$region" --query 'length(InternetGateways)')
    
    # Subnets
    local subnets=$(aws ec2 describe-subnets --region "$region" --query 'length(Subnets)')
    
    # Route Tables
    local route_tables=$(aws ec2 describe-route-tables --region "$region" --query 'length(RouteTables)')
    
    # Security Groups
    local security_groups=$(aws ec2 describe-security-groups --region "$region" --query 'length(SecurityGroups)')
    
    # Network ACLs
    local network_acls=$(aws ec2 describe-network-acls --region "$region" --query 'length(NetworkAcls)')
    
    # Elastic IPs
    local eips=$(aws ec2 describe-addresses --region "$region" --query 'length(Addresses)')
    
    # NAT Gateways
    local nat_gws=$(aws ec2 describe-nat-gateways --region "$region" --query 'length(NatGateways)')
    
    report+="\"vpcs\":$vpcs,\"custom_vpcs\":$custom_vpcs,\"igws\":$igws,\"subnets\":$subnets,"
    report+="\"route_tables\":$route_tables,\"security_groups\":$security_groups,"
    report+="\"network_acls\":$network_acls,\"eips\":$eips,\"nat_gateways\":$nat_gws}"
    
    echo "$report"
}

main() {
    log "🔍 Starting AWS Resource Audit"
    
    echo "{\"audit_date\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"active_region\":\"$ACTIVE_REGION\",\"regions\":[" > "$REPORT_FILE"
    
    local first=true
    for region in $(aws ec2 describe-regions --query 'Regions[].RegionName' --output text); do
        log "Auditing region: $region"
        
        if [[ "$first" == "true" ]]; then
            first=false
        else
            echo "," >> "$REPORT_FILE"
        fi
        
        audit_region "$region" >> "$REPORT_FILE"
    done
    
    echo "]}" >> "$REPORT_FILE"
    
    log "✅ Audit completed: $REPORT_FILE"
    
    # Generate summary
    log "\n📊 SUMMARY:"
    jq -r '
    .regions[] | 
    select(.custom_vpcs > 0 or .nat_gateways > 0 or .eips > 0) |
    "Region: \(.region) - Custom VPCs: \(.custom_vpcs), NAT GWs: \(.nat_gateways), EIPs: \(.eips)"
    ' "$REPORT_FILE" | tee -a "audit.log"
}

main "$@"