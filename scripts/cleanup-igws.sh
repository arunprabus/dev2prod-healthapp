#!/bin/bash

echo "🔍 Checking Internet Gateways..."

# List all IGWs
echo "Current Internet Gateways:"
aws ec2 describe-internet-gateways --query 'InternetGateways[*].[InternetGatewayId,State,Tags[?Key==`Name`].Value|[0]]' --output table

echo ""
echo "🔍 Checking VPC attachments..."

# Check which IGWs are attached to VPCs
aws ec2 describe-internet-gateways --query 'InternetGateways[*].[InternetGatewayId,Attachments[0].VpcId,Attachments[0].State]' --output table

echo ""
echo "🧹 Finding detached IGWs to clean up..."

# Get detached IGWs
DETACHED_IGWS=$(aws ec2 describe-internet-gateways --query 'InternetGateways[?length(Attachments)==`0`].InternetGatewayId' --output text)

if [ -n "$DETACHED_IGWS" ]; then
    echo "Found detached IGWs: $DETACHED_IGWS"
    echo "Cleaning up detached IGWs..."
    
    for igw in $DETACHED_IGWS; do
        echo "Deleting IGW: $igw"
        aws ec2 delete-internet-gateway --internet-gateway-id $igw
    done
else
    echo "No detached IGWs found."
fi

echo ""
echo "🔍 Checking default VPC IGW..."

# Check if default VPC exists and has IGW
DEFAULT_VPC=$(aws ec2 describe-vpcs --filters "Name=is-default,Values=true" --query 'Vpcs[0].VpcId' --output text)

if [ "$DEFAULT_VPC" != "None" ] && [ "$DEFAULT_VPC" != "" ]; then
    echo "Default VPC found: $DEFAULT_VPC"
    
    # Get default VPC IGW
    DEFAULT_IGW=$(aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=$DEFAULT_VPC" --query 'InternetGateways[0].InternetGatewayId' --output text)
    
    if [ "$DEFAULT_IGW" != "None" ] && [ "$DEFAULT_IGW" != "" ]; then
        echo "Default VPC IGW: $DEFAULT_IGW"
        echo "⚠️  Consider if you need the default VPC"
    fi
fi

echo ""
echo "✅ Cleanup complete. Current IGW count:"
aws ec2 describe-internet-gateways --query 'length(InternetGateways)' --output text