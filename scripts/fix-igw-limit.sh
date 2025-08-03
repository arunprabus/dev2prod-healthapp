#!/bin/bash

echo "🚨 IGW Limit Exceeded - Quick Fix Options"
echo "========================================="

echo ""
echo "Option 1: Delete unused VPCs (Recommended)"
echo "aws ec2 describe-vpcs --region ap-south-1 --query 'Vpcs[*].[VpcId,Tags[?Key==\`Name\`].Value|[0],IsDefault]' --output table"
echo "aws ec2 delete-vpc --region ap-south-1 --vpc-id vpc-xxxxxxxxx"

echo ""
echo "Option 2: Use existing VPC"
echo "1. Find existing VPC ID:"
echo "   aws ec2 describe-vpcs --region ap-south-1 --query 'Vpcs[0].VpcId' --output text"
echo ""
echo "2. Update terraform with existing VPC:"
echo "   terraform apply -var-file=envs/shared-vpc.tfvars"

echo ""
echo "Option 3: Deploy to different region"
echo "   Change region in GitHub variables to us-east-1 or eu-west-1"

echo ""
echo "Current status check:"
aws ec2 describe-internet-gateways --region ap-south-1 --query 'length(InternetGateways)' --output text 2>/dev/null || echo "AWS CLI not configured"