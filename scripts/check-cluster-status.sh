#!/bin/bash

echo "🔍 Checking cluster infrastructure status..."

# Check if EC2 instances are running
echo "📊 EC2 Instances:"
aws ec2 describe-instances \
  --filters "Name=tag:Environment,Values=lower" "Name=instance-state-name,Values=running,stopped,pending" \
  --query 'Reservations[].Instances[].{Name:Tags[?Key==`Name`].Value|[0],IP:PublicIpAddress,State:State.Name,Type:InstanceType}' \
  --output table

# Check security groups
echo "🔒 Security Groups for K8s:"
aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=*k8s*,*k3s*" \
  --query 'SecurityGroups[].{Name:GroupName,Rules:IpPermissions[?FromPort==`6443`]}' \
  --output table

# Test connectivity
echo "🌐 Testing connectivity to 43.205.94.176:6443..."
timeout 10 bash -c "</dev/tcp/43.205.94.176/6443" && echo "✅ Port 6443 is reachable" || echo "❌ Port 6443 is not reachable"