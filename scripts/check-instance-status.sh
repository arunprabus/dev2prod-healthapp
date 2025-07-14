#!/bin/bash
# Check EC2 instance status
# Usage: ./check-instance-status.sh

echo "🔍 Checking EC2 instances status..."

# Find all instances with k3s or health-app in name
echo "📋 All running instances:"
aws ec2 describe-instances \
  --filters "Name=instance-state-name,Values=running,stopped,stopping,pending" \
  --query 'Reservations[].Instances[].[Tags[?Key==`Name`].Value|[0],State.Name,PublicIpAddress,InstanceId]' \
  --output table

echo ""
echo "🎯 K3s/Health-app instances specifically:"
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=*k3s*,*health-app*" \
  --query 'Reservations[].Instances[].[Tags[?Key==`Name`].Value|[0],State.Name,PublicIpAddress,InstanceId]' \
  --output table

echo ""
echo "🔌 Testing connectivity to found IPs..."
aws ec2 describe-instances \
  --filters "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].PublicIpAddress' \
  --output text | while read ip; do
    if [[ -n "$ip" && "$ip" != "None" ]]; then
      echo "Testing $ip:22..."
      timeout 5 nc -z $ip 22 && echo "✅ $ip:22 reachable" || echo "❌ $ip:22 not reachable"
    fi
done