#!/bin/bash

# Fixed AWS nuke script

region="ap-south-1"
echo "🧨 Fixed nuke for $region"

# Wait for instances to terminate
sleep 120

# Delete route table associations first
for rt in $(aws ec2 describe-route-tables --region $region --filters "Name=vpc-id,Values=vpc-0a8f11299eebe11f8,vpc-0d6e0494b2b562e55,vpc-0eea42a8bd4ce8e4e" --query 'RouteTables[?Associations[0].Main!=`true`].RouteTableId' --output text); do
    for assoc in $(aws ec2 describe-route-tables --region $region --route-table-ids $rt --query 'RouteTables[].Associations[?Main!=`true`].RouteTableAssociationId' --output text); do
        aws ec2 disassociate-route-table --region $region --association-id $assoc || true
    done
    aws ec2 delete-route-table --region $region --route-table-id $rt || true
done

# Delete IGWs properly
aws ec2 describe-internet-gateways --region $region --query 'InternetGateways[?length(Attachments)>`0`].[InternetGatewayId,Attachments[0].VpcId]' --output text | while read igw_id vpc_id; do
    if [ "$igw_id" != "" ] && [ "$vpc_id" != "" ]; then
        aws ec2 detach-internet-gateway --region $region --internet-gateway-id $igw_id --vpc-id $vpc_id || true
        aws ec2 delete-internet-gateway --region $region --internet-gateway-id $igw_id || true
    fi
done

# Delete subnets
for vpc in vpc-0a8f11299eebe11f8 vpc-0d6e0494b2b562e55 vpc-0eea42a8bd4ce8e4e; do
    for subnet in $(aws ec2 describe-subnets --region $region --filters "Name=vpc-id,Values=$vpc" --query 'Subnets[].SubnetId' --output text); do
        aws ec2 delete-subnet --region $region --subnet-id $subnet || true
    done
done

# Delete VPCs
sleep 30
for vpc in vpc-0a8f11299eebe11f8 vpc-0d6e0494b2b562e55 vpc-0eea42a8bd4ce8e4e; do
    aws ec2 delete-vpc --region $region --vpc-id $vpc || true
done

echo "✅ Fixed nuke complete"