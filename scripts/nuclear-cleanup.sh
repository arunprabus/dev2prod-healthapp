#!/bin/bash
set -e

NETWORK_TIER=${1:-lower}
MODE=${2:-initial}

echo "☢️ NUCLEAR CLEANUP for $NETWORK_TIER environment (mode: $MODE)"

# Terminate all EC2 instances
echo "🔥 Terminating all EC2 instances..."
INSTANCES=$(aws ec2 describe-instances --filters "Name=tag:Project,Values=health-app" "Name=instance-state-name,Values=running,stopped,stopping" --query "Reservations[].Instances[].InstanceId" --output text)
if [ -n "$INSTANCES" ]; then
  echo $INSTANCES | xargs -n1 aws ec2 terminate-instances --instance-ids || true
  echo "⏳ Waiting for instances to terminate..."
  sleep 60
fi

# Delete all RDS instances
echo "🗄️ Deleting all RDS instances..."
aws rds describe-db-instances --query "DBInstances[?contains(DBInstanceIdentifier, 'health-app')].DBInstanceIdentifier" --output text | xargs -I {} aws rds delete-db-instance --db-instance-identifier {} --skip-final-snapshot --delete-automated-backups || true

# Delete security groups
echo "🛡️ Deleting security groups..."
aws ec2 describe-security-groups --filters "Name=tag:Project,Values=health-app" --query "SecurityGroups[].GroupId" --output text | xargs -I {} aws ec2 delete-security-group --group-id {} || true

# Delete VPCs
echo "🌐 Deleting VPCs..."
VPC_IDS=$(aws ec2 describe-vpcs --filters "Name=tag:Project,Values=health-app" --query "Vpcs[].VpcId" --output text)
for VPC_ID in $VPC_IDS; do
  echo "Deleting VPC: $VPC_ID"
  
  # Delete subnets
  aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --query "Subnets[].SubnetId" --output text | xargs -I {} aws ec2 delete-subnet --subnet-id {} || true
  
  # Delete route tables
  aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$VPC_ID" --query "RouteTables[?Associations[0].Main!=\`true\`].RouteTableId" --output text | xargs -I {} aws ec2 delete-route-table --route-table-id {} || true
  
  # Delete internet gateways
  aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=$VPC_ID" --query "InternetGateways[].InternetGatewayId" --output text | xargs -I {} sh -c 'aws ec2 detach-internet-gateway --internet-gateway-id $1 --vpc-id '$VPC_ID' && aws ec2 delete-internet-gateway --internet-gateway-id $1' _ {} || true
  
  # Delete VPC
  aws ec2 delete-vpc --vpc-id $VPC_ID || true
done

# Delete key pairs
echo "🔑 Deleting key pairs..."
aws ec2 describe-key-pairs --filters "Name=key-name,Values=health-app-*" --query "KeyPairs[].KeyName" --output text | xargs -I {} aws ec2 delete-key-pair --key-name {} || true

# Delete IAM roles and policies
echo "👤 Deleting IAM resources..."
aws iam list-roles --query "Roles[?contains(RoleName, 'health-app')].RoleName" --output text | xargs -I {} sh -c 'aws iam list-attached-role-policies --role-name $1 --query "AttachedPolicies[].PolicyArn" --output text | xargs -I {} aws iam detach-role-policy --role-name $1 --policy-arn {} || true; aws iam list-role-policies --role-name $1 --query "PolicyNames[]" --output text | xargs -I {} aws iam delete-role-policy --role-name $1 --policy-name {} || true; aws iam list-instance-profiles-for-role --role-name $1 --query "InstanceProfiles[].InstanceProfileName" --output text | xargs -I {} sh -c "aws iam remove-role-from-instance-profile --instance-profile-name {} --role-name $1 || true; aws iam delete-instance-profile --instance-profile-name {} || true"; aws iam delete-role --role-name $1 || true' _ {} || true

echo "☢️ Nuclear cleanup completed for $NETWORK_TIER"