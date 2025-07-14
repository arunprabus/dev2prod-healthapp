#!/bin/bash
# Fix security groups to allow SSH access
# Usage: ./fix-security-groups.sh

echo "🔒 Checking and fixing security groups..."

# Get security groups for running instances
echo "📋 Current security groups:"
aws ec2 describe-instances \
  --filters "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].[InstanceId,SecurityGroups[].GroupId]' \
  --output table

# Get all security group IDs
SG_IDS=$(aws ec2 describe-instances \
  --filters "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].SecurityGroups[].GroupId' \
  --output text | tr '\t' '\n' | sort -u)

echo ""
echo "🔍 Checking SSH access for each security group..."

for sg_id in $SG_IDS; do
  echo "Checking $sg_id..."
  
  # Check if SSH rule exists
  SSH_RULE=$(aws ec2 describe-security-groups \
    --group-ids $sg_id \
    --query 'SecurityGroups[0].IpPermissions[?FromPort==`22`]' \
    --output text)
  
  if [[ -z "$SSH_RULE" ]]; then
    echo "❌ No SSH rule found in $sg_id - Adding SSH access..."
    
    # Add SSH rule
    aws ec2 authorize-security-group-ingress \
      --group-id $sg_id \
      --protocol tcp \
      --port 22 \
      --cidr 0.0.0.0/0 \
      && echo "✅ SSH access added to $sg_id" \
      || echo "❌ Failed to add SSH access to $sg_id"
  else
    echo "✅ SSH rule exists in $sg_id"
  fi
done

echo ""
echo "🧪 Testing connectivity again..."
aws ec2 describe-instances \
  --filters "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].PublicIpAddress' \
  --output text | tr '\t' '\n' | while read ip; do
    if [[ -n "$ip" && "$ip" != "None" ]]; then
      echo "Testing $ip:22..."
      timeout 5 nc -z $ip 22 && echo "✅ $ip:22 reachable" || echo "❌ $ip:22 still not reachable"
    fi
done