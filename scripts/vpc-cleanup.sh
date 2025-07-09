#!/bin/bash
# VPC Cleanup - Remove unused VPCs and dependencies

REGION=${1:-ap-south-1}

echo "🧹 VPC Cleanup for region: $REGION"

# Get all VPCs except default
# Force delete all RDS instances first
echo "🗄️ Force deleting all RDS instances..."
aws rds describe-db-instances --region $REGION --query "DBInstances[].DBInstanceIdentifier" --output text | tr '\t' '\n' | while read -r db; do
    if [ -n "$db" ]; then
        echo "Deleting RDS: $db"
        aws rds delete-db-instance --region $REGION --db-instance-identifier "$db" --skip-final-snapshot --delete-automated-backups || true
    fi
done

# Wait for RDS deletion
echo "⏳ Waiting for RDS instances to be deleted..."
sleep 60

# Delete DB subnet groups
echo "🗑️ Deleting DB subnet groups..."
aws rds describe-db-subnet-groups --region $REGION --query "DBSubnetGroups[].DBSubnetGroupName" --output text | tr '\t' '\n' | while read -r sg; do
    if [ -n "$sg" ]; then
        echo "Deleting DB subnet group: $sg"
        aws rds delete-db-subnet-group --region $REGION --db-subnet-group-name "$sg" || true
    fi
done

# Now clean VPCs
VPC_IDS=$(aws ec2 describe-vpcs --region $REGION --query "Vpcs[?IsDefault==\`false\`].VpcId" --output text)

for VPC_ID in $VPC_IDS; do
    echo "🗑️ Cleaning VPC: $VPC_ID"
    
    # Delete security groups (except default)
    aws ec2 describe-security-groups --region $REGION --filters "Name=vpc-id,Values=$VPC_ID" --query "SecurityGroups[?GroupName!=\`default\`].GroupId" --output text | tr '\t' '\n' | while read -r sg; do
        [ -n "$sg" ] && aws ec2 delete-security-group --region $REGION --group-id "$sg" || true
    done
    
    # Delete subnets
    aws ec2 describe-subnets --region $REGION --filters "Name=vpc-id,Values=$VPC_ID" --query "Subnets[].SubnetId" --output text | tr '\t' '\n' | while read -r subnet; do
        [ -n "$subnet" ] && aws ec2 delete-subnet --region $REGION --subnet-id "$subnet" || true
    done
    
    # Delete route tables (except main)
    aws ec2 describe-route-tables --region $REGION --filters "Name=vpc-id,Values=$VPC_ID" --query "RouteTables[?Associations[0].Main!=\`true\`].RouteTableId" --output text | tr '\t' '\n' | while read -r rt; do
        [ -n "$rt" ] && aws ec2 delete-route-table --region $REGION --route-table-id "$rt" || true
    done
    
    # Detach and delete internet gateways
    aws ec2 describe-internet-gateways --region $REGION --filters "Name=attachment.vpc-id,Values=$VPC_ID" --query "InternetGateways[].InternetGatewayId" --output text | while read IGW_ID; do
        aws ec2 detach-internet-gateway --region $REGION --internet-gateway-id $IGW_ID --vpc-id $VPC_ID
        aws ec2 delete-internet-gateway --region $REGION --internet-gateway-id $IGW_ID
    done
    
    # Delete VPC
    aws ec2 delete-vpc --region $REGION --vpc-id $VPC_ID && echo "✅ Deleted VPC: $VPC_ID" || echo "❌ Failed to delete VPC: $VPC_ID"
done

echo "✅ VPC cleanup complete"