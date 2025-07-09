#!/bin/bash
# Enhanced VPC Cleanup - Remove all dependencies first

REGION=${1:-ap-south-1}
ALL_REGIONS=${2:-false}

cleanup_region() {
    local region=$1
    echo "🧹 Complete cleanup for region: $region"
    
    # 1. Force terminate ALL EC2 instances
    echo "🛑 Terminating all EC2 instances..."
    aws ec2 describe-instances --region $region --query "Reservations[].Instances[?State.Name!='terminated'].InstanceId" --output text | tr '\t' '\n' | while read -r instance; do
        if [ -n "$instance" ]; then
            echo "Terminating instance: $instance"
            aws ec2 terminate-instances --region $region --instance-ids "$instance" || true
        fi
    done
    
    # 2. Force delete ALL RDS instances
    echo "🗄️ Force deleting all RDS instances..."
    aws rds describe-db-instances --region $region --query "DBInstances[].DBInstanceIdentifier" --output text | tr '\t' '\n' | while read -r db; do
        if [ -n "$db" ]; then
            echo "Deleting RDS: $db"
            aws rds delete-db-instance --region $region --db-instance-identifier "$db" --skip-final-snapshot --delete-automated-backups || true
        fi
    done
    
    # 3. Wait for resources to terminate
    echo "⏳ Waiting for resources to terminate..."
    sleep 120
    
    # 4. Delete all DB subnet groups
    echo "🗑️ Deleting all DB subnet groups..."
    aws rds describe-db-subnet-groups --region $region --query "DBSubnetGroups[].DBSubnetGroupName" --output text | tr '\t' '\n' | while read -r sg; do
        if [ -n "$sg" ] && [ "$sg" != "default" ]; then
            echo "Deleting DB subnet group: $sg"
            aws rds delete-db-subnet-group --region $region --db-subnet-group-name "$sg" || true
        fi
    done
    
    # 5. Release all Elastic IPs
    echo "🌐 Releasing Elastic IPs..."
    aws ec2 describe-addresses --region $region --query "Addresses[].AllocationId" --output text | tr '\t' '\n' | while read -r eip; do
        if [ -n "$eip" ]; then
            echo "Releasing EIP: $eip"
            aws ec2 release-address --region $region --allocation-id "$eip" || true
        fi
    done
    
    # 6. Delete NAT Gateways
    echo "🚪 Deleting NAT Gateways..."
    aws ec2 describe-nat-gateways --region $region --query "NatGateways[?State!='deleted'].NatGatewayId" --output text | tr '\t' '\n' | while read -r nat; do
        if [ -n "$nat" ]; then
            echo "Deleting NAT Gateway: $nat"
            aws ec2 delete-nat-gateway --region $region --nat-gateway-id "$nat" || true
        fi
    done
    
    # 7. Wait for NAT Gateways to delete
    echo "⏳ Waiting for NAT Gateways to delete..."
    sleep 60
    
    # 8. Clean VPCs
    VPC_IDS=$(aws ec2 describe-vpcs --region $region --query "Vpcs[?IsDefault==\`false\`].VpcId" --output text)
    
    for VPC_ID in $VPC_IDS; do
        echo "🗑️ Cleaning VPC: $VPC_ID"
        
        # Delete security groups (multiple passes)
        for i in {1..3}; do
            aws ec2 describe-security-groups --region $region --filters "Name=vpc-id,Values=$VPC_ID" --query "SecurityGroups[?GroupName!=\`default\`].GroupId" --output text | tr '\t' '\n' | while read -r sg; do
                [ -n "$sg" ] && aws ec2 delete-security-group --region $region --group-id "$sg" 2>/dev/null || true
            done
            sleep 10
        done
        
        # Delete subnets (multiple passes)
        for i in {1..3}; do
            aws ec2 describe-subnets --region $region --filters "Name=vpc-id,Values=$VPC_ID" --query "Subnets[].SubnetId" --output text | tr '\t' '\n' | while read -r subnet; do
                [ -n "$subnet" ] && aws ec2 delete-subnet --region $region --subnet-id "$subnet" 2>/dev/null || true
            done
            sleep 10
        done
        
        # Delete route tables
        aws ec2 describe-route-tables --region $region --filters "Name=vpc-id,Values=$VPC_ID" --query "RouteTables[?Associations[0].Main!=\`true\`].RouteTableId" --output text | tr '\t' '\n' | while read -r rt; do
            [ -n "$rt" ] && aws ec2 delete-route-table --region $region --route-table-id "$rt" 2>/dev/null || true
        done
        
        # Detach and delete internet gateways
        aws ec2 describe-internet-gateways --region $region --filters "Name=attachment.vpc-id,Values=$VPC_ID" --query "InternetGateways[].InternetGatewayId" --output text | while read IGW_ID; do
            if [ -n "$IGW_ID" ]; then
                aws ec2 detach-internet-gateway --region $region --internet-gateway-id $IGW_ID --vpc-id $VPC_ID 2>/dev/null || true
                sleep 5
                aws ec2 delete-internet-gateway --region $region --internet-gateway-id $IGW_ID 2>/dev/null || true
            fi
        done
        
        # Delete VPC
        aws ec2 delete-vpc --region $region --vpc-id $VPC_ID && echo "✅ Deleted VPC: $VPC_ID" || echo "❌ Failed to delete VPC: $VPC_ID"
    done
}

if [ "$ALL_REGIONS" = "true" ]; then
    echo "🌍 Cleaning up common regions only..."
    # Only clean commonly used regions to avoid infinite loop
    for region in "us-east-1" "us-west-2" "eu-west-1" "ap-south-1" "ap-southeast-1"; do
        echo "🌍 Cleaning region: $region"
        cleanup_region "$region"
    done
else
    cleanup_region "$REGION"
fi

echo "✅ VPC cleanup complete"