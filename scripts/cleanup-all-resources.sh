#!/bin/bash

# Cleanup all AWS resources across regions
echo "🧹 Starting comprehensive AWS cleanup..."

# List of regions to clean
REGIONS=(
  "ap-south-1" "ap-northeast-1" "ap-northeast-2" "ap-northeast-3" 
  "ap-southeast-1" "ap-southeast-2" "us-east-1" "us-east-2" 
  "us-west-1" "us-west-2" "eu-west-1" "eu-west-2" "eu-west-3" 
  "eu-central-1" "eu-north-1" "ca-central-1" "sa-east-1"
)

cleanup_region() {
  local region=$1
  echo "🌍 Cleaning region: $region"
  
  # Terminate all EC2 instances
  echo "  Terminating EC2 instances..."
  aws ec2 describe-instances --region $region --query 'Reservations[].Instances[?State.Name!=`terminated`].InstanceId' --output text | \
    xargs -r -n1 aws ec2 terminate-instances --region $region --instance-ids 2>/dev/null || true
  
  # Wait for instances to terminate
  sleep 30
  
  # Delete all non-default VPCs
  echo "  Deleting VPCs..."
  for vpc in $(aws ec2 describe-vpcs --region $region --filters "Name=is-default,Values=false" --query "Vpcs[].VpcId" --output text); do
    echo "    Deleting VPC: $vpc"
    
    # Delete subnets
    aws ec2 describe-subnets --region $region --filters "Name=vpc-id,Values=$vpc" --query "Subnets[].SubnetId" --output text | \
      xargs -r -n1 aws ec2 delete-subnet --region $region --subnet-id 2>/dev/null || true
    
    # Delete internet gateways
    for igw in $(aws ec2 describe-internet-gateways --region $region --filters "Name=attachment.vpc-id,Values=$vpc" --query "InternetGateways[].InternetGatewayId" --output text); do
      aws ec2 detach-internet-gateway --region $region --internet-gateway-id $igw --vpc-id $vpc 2>/dev/null || true
      aws ec2 delete-internet-gateway --region $region --internet-gateway-id $igw 2>/dev/null || true
    done
    
    # Delete route tables (except main)
    aws ec2 describe-route-tables --region $region --filters "Name=vpc-id,Values=$vpc" "Name=association.main,Values=false" --query "RouteTables[].RouteTableId" --output text | \
      xargs -r -n1 aws ec2 delete-route-table --region $region --route-table-id 2>/dev/null || true
    
    # Delete security groups (except default)
    aws ec2 describe-security-groups --region $region --filters "Name=vpc-id,Values=$vpc" --query "SecurityGroups[?GroupName!='default'].GroupId" --output text | \
      xargs -r -n1 aws ec2 delete-security-group --region $region --group-id 2>/dev/null || true
    
    # Delete VPC
    aws ec2 delete-vpc --region $region --vpc-id $vpc 2>/dev/null || true
  done
  
  # Delete key pairs
  echo "  Deleting key pairs..."
  aws ec2 describe-key-pairs --region $region --query "KeyPairs[].KeyName" --output text | \
    xargs -r -n1 aws ec2 delete-key-pair --region $region --key-name 2>/dev/null || true
  
  # Delete volumes
  echo "  Deleting volumes..."
  aws ec2 describe-volumes --region $region --filters "Name=status,Values=available" --query "Volumes[].VolumeId" --output text | \
    xargs -r -n1 aws ec2 delete-volume --region $region --volume-id 2>/dev/null || true
}

# Clean up IAM resources (global)
echo "🔐 Cleaning IAM resources..."
for role in $(aws iam list-roles --query "Roles[?contains(RoleName, 'health-app')].RoleName" --output text); do
  echo "  Deleting IAM role: $role"
  # Detach managed policies
  aws iam list-attached-role-policies --role-name $role --query "AttachedPolicies[].PolicyArn" --output text | \
    xargs -r -n1 aws iam detach-role-policy --role-name $role --policy-arn 2>/dev/null || true
  # Delete inline policies
  aws iam list-role-policies --role-name $role --query "PolicyNames[]" --output text | \
    xargs -r -n1 aws iam delete-role-policy --role-name $role --policy-name 2>/dev/null || true
  # Remove from instance profiles
  aws iam list-instance-profiles-for-role --role-name $role --query "InstanceProfiles[].InstanceProfileName" --output text | \
    xargs -r -n1 aws iam remove-role-from-instance-profile --role-name $role --instance-profile-name 2>/dev/null || true
  # Delete role
  aws iam delete-role --role-name $role 2>/dev/null || true
done

# Delete instance profiles
for profile in $(aws iam list-instance-profiles --query "InstanceProfiles[?contains(InstanceProfileName, 'health-app')].InstanceProfileName" --output text); do
  echo "  Deleting instance profile: $profile"
  aws iam delete-instance-profile --instance-profile-name $profile 2>/dev/null || true
done

# Delete custom policies
for policy in $(aws iam list-policies --scope Local --query "Policies[?contains(PolicyName, 'health-app')].Arn" --output text); do
  echo "  Deleting policy: $policy"
  aws iam delete-policy --policy-arn $policy 2>/dev/null || true
done

# Clean each region
for region in "${REGIONS[@]}"; do
  cleanup_region $region
done

echo "✅ Cleanup complete!"
echo "📊 Remaining resources:"
aws ec2 describe-vpcs --region ap-south-1 --query "Vpcs[].{VpcId:VpcId,IsDefault:IsDefault}" --output table