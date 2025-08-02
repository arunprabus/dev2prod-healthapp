#!/bin/bash

echo "🔍 Debugging K3s installation for $1 environment..."

# Get K3s instance details
K3S_DETAILS=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=health-app-$1-k3s-node" "Name=instance-state-name,Values=running" \
  --query "Reservations[0].Instances[0].[InstanceId,PublicIpAddress,State.Name]" --output text)

if [ "$K3S_DETAILS" = "None" ]; then
  echo "❌ No K3s instance found for $1 environment"
  exit 1
fi

K3S_INSTANCE_ID=$(echo $K3S_DETAILS | cut -d' ' -f1)
K3S_IP=$(echo $K3S_DETAILS | cut -d' ' -f2)
K3S_STATE=$(echo $K3S_DETAILS | cut -d' ' -f3)

echo "📋 Instance Details:"
echo "  ID: $K3S_INSTANCE_ID"
echo "  IP: $K3S_IP"
echo "  State: $K3S_STATE"

# Check instance status
echo ""
echo "🔍 Instance Status:"
aws ec2 describe-instance-status --instance-ids $K3S_INSTANCE_ID --query "InstanceStatuses[0].[SystemStatus.Status,InstanceStatus.Status]" --output table

# Check security groups
echo ""
echo "🔍 Security Groups:"
aws ec2 describe-instances --instance-ids $K3S_INSTANCE_ID --query "Reservations[0].Instances[0].SecurityGroups[*].[GroupName,GroupId]" --output table

# Try to connect via SSH (if SSH key is available)
echo ""
echo "🔍 SSH Connection Test:"
if [ -f ~/.ssh/k3s-key ]; then
  echo "Testing SSH connection..."
  timeout 10 ssh -i ~/.ssh/k3s-key -o ConnectTimeout=5 -o StrictHostKeyChecking=no ubuntu@$K3S_IP "echo 'SSH connection successful'" 2>/dev/null || echo "SSH connection failed"
else
  echo "SSH key not found at ~/.ssh/k3s-key"
fi

# Check if K3s API is responding
echo ""
echo "🔍 K3s API Test:"
timeout 10 curl -k https://$K3S_IP:6443/version 2>/dev/null && echo "K3s API is responding" || echo "K3s API not responding"

echo ""
echo "✅ Debug complete for $1 environment"