#!/bin/bash
echo "🔍 Verifying cleanup..."

echo "EC2 Instances (should be empty):"
aws ec2 describe-instances --region ap-south-1 --query 'Reservations[].Instances[?State.Name!=`terminated`].[InstanceId,State.Name]' --output table

echo "RDS Instances (should be empty):"
aws rds describe-db-instances --region ap-south-1 --query 'DBInstances[].DBInstanceIdentifier' --output table

echo "Custom Security Groups (should be empty):"
aws ec2 describe-security-groups --region ap-south-1 --filters 'Name=tag:Project,Values=Learning' --query 'SecurityGroups[].GroupId' --output table

echo "✅ Verification complete"