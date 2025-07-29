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

# Check GitHub Runner Resources
echo "🖥️ GitHub Runner Resource Usage:"
echo "CPU Usage:"
top -bn1 | grep "Cpu(s)" || echo "Failed to get CPU info"

echo "Memory Usage:"
free -h || echo "Failed to get memory info"

echo "Disk Usage:"
df -h / || echo "Failed to get disk info"

echo "Load Average:"
uptime || echo "Failed to get uptime"

echo "Active Processes:"
ps aux --sort=-%cpu | head -10 || echo "Failed to get process info"

echo "Network Connections:"
netstat -tuln | grep -E ':(22|6443|443|80)' || echo "Failed to get network info"

# Check CloudWatch metrics if available
echo "📈 Instance Metrics (if available):"
for IP in "13.232.75.155" "13.127.158.59"; do
  INSTANCE_ID=$(aws ec2 describe-instances \
    --filters "Name=private-ip-address,Values=$IP" \
    --query 'Reservations[0].Instances[0].InstanceId' \
    --output text 2>/dev/null)
  
  if [ "$INSTANCE_ID" != "None" ] && [ -n "$INSTANCE_ID" ]; then
    echo "Metrics for $IP ($INSTANCE_ID):"
    aws cloudwatch get-metric-statistics \
      --namespace AWS/EC2 \
      --metric-name CPUUtilization \
      --dimensions Name=InstanceId,Value=$INSTANCE_ID \
      --start-time $(date -u -d '10 minutes ago' +%Y-%m-%dT%H:%M:%S) \
      --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
      --period 300 \
      --statistics Average \
      --query 'Datapoints[0].Average' \
      --output text 2>/dev/null || echo "No CPU metrics available"
  fi
done

# Test runner's ability to make external connections
echo "🌐 Runner External Connectivity:"
echo "GitHub API test:"
timeout 10 curl -s https://api.github.com/zen || echo "GitHub API failed"

echo "AWS API test:"
timeout 10 aws sts get-caller-identity --query 'Account' --output text || echo "AWS API failed"

echo "DNS test:"
nslookup github.com || echo "DNS resolution failed"

echo "🎯 Complete resource and connectivity test finished!"