#!/bin/bash
set -e

NETWORK_TIER=${1:-lower}

echo "☢️ NUCLEAR CLEANUP for $NETWORK_TIER environment"

# Get VPC ID
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=health-app-$NETWORK_TIER-vpc" --query 'Vpcs[0].VpcId' --output text 2>/dev/null || echo "")

if [ "$VPC_ID" == "" ] || [ "$VPC_ID" == "None" ]; then
  echo "No VPC found for $NETWORK_TIER network"
  exit 0
fi

echo "Found VPC: $VPC_ID"

# 1. Delete RDS instances
echo "🗑️ Deleting RDS instances..."
aws rds describe-db-instances --query 'DBInstances[?contains(DBInstanceIdentifier, `health-app`)].DBInstanceIdentifier' --output text | tr '\t' '\n' | while read DB_ID; do
  if [ "$DB_ID" != "" ]; then
    aws rds delete-db-instance --db-instance-identifier "$DB_ID" --skip-final-snapshot --delete-automated-backups || true
  fi
done

# 2. Terminate EC2 instances
echo "🗑️ Terminating EC2 instances..."
aws ec2 describe-instances --filters "Name=vpc-id,Values=$VPC_ID" "Name=instance-state-name,Values=running,stopped" --query 'Reservations[].Instances[].InstanceId' --output text | tr '\t' '\n' | while read INSTANCE_ID; do
  if [ "$INSTANCE_ID" != "" ]; then
    aws ec2 terminate-instances --instance-ids "$INSTANCE_ID" || true
  fi
done

sleep 60

# 3. Delete Security Groups
echo "🗑️ Deleting Security Groups..."
aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$VPC_ID" --query 'SecurityGroups[?GroupName!=`default`].GroupId' --output text | tr '\t' '\n' | while read SG_ID; do
  if [ "$SG_ID" != "" ]; then
    aws ec2 delete-security-group --group-id "$SG_ID" || true
  fi
done

# 4. Delete Route Tables
echo "🗑️ Deleting Route Tables..."
aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$VPC_ID" --query 'RouteTables[?Associations[0].Main!=`true`].RouteTableId' --output text | tr '\t' '\n' | while read RT_ID; do
  if [ "$RT_ID" != "" ]; then
    aws ec2 delete-route-table --route-table-id "$RT_ID" || true
  fi
done

# 5. Delete Subnets
echo "🗑️ Deleting Subnets..."
aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --query 'Subnets[].SubnetId' --output text | tr '\t' '\n' | while read SUBNET_ID; do
  if [ "$SUBNET_ID" != "" ]; then
    aws ec2 delete-subnet --subnet-id "$SUBNET_ID" || true
  fi
done

# 6. Delete Internet Gateway
echo "🗑️ Deleting Internet Gateway..."
aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=$VPC_ID" --query 'InternetGateways[].InternetGatewayId' --output text | tr '\t' '\n' | while read IGW_ID; do
  if [ "$IGW_ID" != "" ]; then
    aws ec2 detach-internet-gateway --internet-gateway-id "$IGW_ID" --vpc-id "$VPC_ID" || true
    aws ec2 delete-internet-gateway --internet-gateway-id "$IGW_ID" || true
  fi
done

# 7. Delete VPC
echo "🗑️ Deleting VPC..."
aws ec2 delete-vpc --vpc-id "$VPC_ID" || true

# 8. Delete key pairs and IAM
echo "🗑️ Deleting key pairs..."
aws ec2 describe-key-pairs --filters "Name=key-name,Values=health-app-*" --query "KeyPairs[].KeyName" --output text | xargs -I {} aws ec2 delete-key-pair --key-name {} || true

echo "🗑️ Deleting IAM resources..."
aws iam list-roles --query "Roles[?contains(RoleName, 'health-app')].RoleName" --output text | tr '\t' '\n' | while read ROLE_NAME; do
  if [ "$ROLE_NAME" != "" ]; then
    aws iam list-attached-role-policies --role-name "$ROLE_NAME" --query "AttachedPolicies[].PolicyArn" --output text | xargs -I {} aws iam detach-role-policy --role-name "$ROLE_NAME" --policy-arn {} || true
    aws iam list-role-policies --role-name "$ROLE_NAME" --query "PolicyNames[]" --output text | xargs -I {} aws iam delete-role-policy --role-name "$ROLE_NAME" --policy-name {} || true
    aws iam list-instance-profiles-for-role --role-name "$ROLE_NAME" --query "InstanceProfiles[].InstanceProfileName" --output text | xargs -I {} sh -c "aws iam remove-role-from-instance-profile --instance-profile-name {} --role-name $ROLE_NAME || true; aws iam delete-instance-profile --instance-profile-name {} || true" || true
    aws iam delete-role --role-name "$ROLE_NAME" || true
  fi
done

echo "☢️ Nuclear cleanup completed for $NETWORK_TIER"