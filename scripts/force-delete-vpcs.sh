#!/bin/bash

# Force delete VPCs by removing all dependencies first

VPCS="vpc-08b6209dee1989b54 vpc-0a8f11299eebe11f8 vpc-0d6e0494b2b562e55 vpc-047ff1c7c0e7199fb vpc-0131cb7b9232c3cfc vpc-0eea42a8bd4ce8e4e"

for vpc in $VPCS; do
    echo "🗑️ Force deleting VPC: $vpc"
    
    # Delete NAT Gateways
    for nat in $(aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=$vpc" --query 'NatGateways[].NatGatewayId' --output text); do
        aws ec2 delete-nat-gateway --nat-gateway-id $nat
    done
    
    # Delete Internet Gateways
    for igw in $(aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=$vpc" --query 'InternetGateways[].InternetGatewayId' --output text); do
        aws ec2 detach-internet-gateway --internet-gateway-id $igw --vpc-id $vpc
        aws ec2 delete-internet-gateway --internet-gateway-id $igw
    done
    
    # Delete Route Tables (except main)
    for rt in $(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$vpc" --query 'RouteTables[?Associations[0].Main!=`true`].RouteTableId' --output text); do
        aws ec2 delete-route-table --route-table-id $rt
    done
    
    # Delete Security Groups (except default)
    for sg in $(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$vpc" --query 'SecurityGroups[?GroupName!=`default`].GroupId' --output text); do
        aws ec2 delete-security-group --group-id $sg
    done
    
    # Delete Network ACLs (except default)
    for acl in $(aws ec2 describe-network-acls --filters "Name=vpc-id,Values=$vpc" --query 'NetworkAcls[?IsDefault!=`true`].NetworkAclId' --output text); do
        aws ec2 delete-network-acl --network-acl-id $acl
    done
    
    # Delete Subnets
    for subnet in $(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$vpc" --query 'Subnets[].SubnetId' --output text); do
        aws ec2 delete-subnet --subnet-id $subnet
    done
    
    # Wait for dependencies to clear
    sleep 10
    
    # Delete VPC
    aws ec2 delete-vpc --vpc-id $vpc && echo "✅ Deleted $vpc" || echo "❌ Failed to delete $vpc"
done