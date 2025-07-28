#!/bin/bash
# Debug K3s connectivity issues

DEV_IP="43.205.210.144"
TEST_IP="43.204.141.137"

echo "🔍 Debugging K3s connectivity..."

echo "=== Network Tests ==="
echo "Testing dev cluster ($DEV_IP):"
nc -zv $DEV_IP 6443 || echo "Port 6443 not reachable"
curl -k --connect-timeout 5 https://$DEV_IP:6443/version || echo "HTTPS not responding"

echo "Testing test cluster ($TEST_IP):"
nc -zv $TEST_IP 6443 || echo "Port 6443 not reachable"
curl -k --connect-timeout 5 https://$TEST_IP:6443/version || echo "HTTPS not responding"

echo "=== Security Group Check ==="
aws ec2 describe-security-groups --filters "Name=group-name,Values=*k3s*" --query "SecurityGroups[*].[GroupName,GroupId]" --output table

echo "=== Instance Status ==="
aws ec2 describe-instances --filters "Name=tag:Name,Values=*k3s*" "Name=instance-state-name,Values=running" --query "Reservations[*].Instances[*].[InstanceId,Tags[?Key=='Name'].Value|[0],PublicIpAddress,SecurityGroups[0].GroupId]" --output table