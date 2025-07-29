#!/bin/bash

echo "🔍 Simple connectivity test..."

CLUSTERS=("13.232.75.155" "13.127.158.59")
NAMES=("dev" "test")

for i in "${!CLUSTERS[@]}"; do
  IP="${CLUSTERS[$i]}"
  NAME="${NAMES[$i]}"
  
  echo "📡 Testing $NAME cluster ($IP)..."
  
  # Test port connectivity
  echo "Port 22 (SSH):"
  timeout 10 bash -c "</dev/tcp/$IP/22" 2>/dev/null && echo "✅ Open" || echo "❌ Closed/Timeout"
  
  echo "Port 6443 (K3s API):"
  timeout 10 bash -c "</dev/tcp/$IP/6443" 2>/dev/null && echo "✅ Open" || echo "❌ Closed/Timeout"
  
  # Test HTTP response
  echo "K3s API HTTP test:"
  timeout 10 curl -k -s -m 5 "https://$IP:6443/version" 2>/dev/null && echo "✅ API responding" || echo "❌ API not responding"
  
  # Test ping
  echo "Ping test:"
  ping -c 2 -W 3 "$IP" >/dev/null 2>&1 && echo "✅ Ping OK" || echo "❌ Ping failed"
  
  echo "----------------------------------------"
done

# Check if instances are still running
echo "📊 AWS Instance Status:"
aws ec2 describe-instances \
  --instance-ids $(aws ec2 describe-instances \
    --filters "Name=tag:Environment,Values=lower" "Name=instance-state-name,Values=running" \
    --query 'Reservations[].Instances[].InstanceId' \
    --output text) \
  --query 'Reservations[].Instances[].[Tags[?Key==`Name`].Value|[0],State.Name,StatusChecks.SystemStatus.Status,StatusChecks.InstanceStatus.Status]' \
  --output table 2>/dev/null || echo "Failed to get instance status"

echo "🎯 Connectivity test complete!"