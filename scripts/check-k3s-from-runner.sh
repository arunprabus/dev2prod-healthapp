#!/bin/bash

# Check K3s clusters from GitHub runner
echo "🔍 Checking K3s clusters from runner..."

# Get current cluster IPs from terraform or AWS
echo "📡 Getting cluster IPs..."
DEV_IP=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=health-app-lower-dev-k3s-node-v2" \
           "Name=instance-state-name,Values=running" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text 2>/dev/null)

TEST_IP=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=health-app-lower-test-k3s-node-v2" \
           "Name=instance-state-name,Values=running" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text 2>/dev/null)

echo "Dev cluster IP: $DEV_IP"
echo "Test cluster IP: $TEST_IP"

# Test API connectivity
echo -e "\n🌐 Testing K3s API connectivity..."
for IP in "$DEV_IP" "$TEST_IP"; do
  if [ "$IP" != "None" ] && [ -n "$IP" ]; then
    echo "Testing $IP:6443..."
    if timeout 10 curl -k -s "https://$IP:6443/version" >/dev/null 2>&1; then
      echo "✅ $IP:6443 - API responding"
      # Get version info
      curl -k -s "https://$IP:6443/version" | jq . 2>/dev/null || echo "API responding but no JSON"
    else
      echo "❌ $IP:6443 - API not responding"
    fi
    
    # Test SSH connectivity
    echo "Testing SSH to $IP..."
    if timeout 5 bash -c "</dev/tcp/$IP/22" 2>/dev/null; then
      echo "✅ $IP:22 - SSH port open"
    else
      echo "❌ $IP:22 - SSH port closed"
    fi
  else
    echo "⚠️ IP not found or instance not running"
  fi
done

# Check Parameter Store values
echo -e "\n📋 Checking Parameter Store..."
echo "Dev cluster server:"
aws ssm get-parameter --name "/dev/health-app/kubeconfig/server" --query 'Parameter.Value' --output text 2>/dev/null || echo "❌ Not found"

echo "Test cluster server:"
aws ssm get-parameter --name "/test/health-app/kubeconfig/server" --query 'Parameter.Value' --output text 2>/dev/null || echo "❌ Not found"

# Try SSH connection to check K3s status
echo -e "\n🔧 Attempting SSH connection to check K3s..."
for IP in "$DEV_IP" "$TEST_IP"; do
  if [ "$IP" != "None" ] && [ -n "$IP" ]; then
    echo "Checking K3s on $IP via SSH..."
    
    # Use the SSH key from secrets
    if ssh -i ~/.ssh/k3s-key -o StrictHostKeyChecking=no -o ConnectTimeout=10 ubuntu@$IP 'sudo systemctl is-active k3s' 2>/dev/null; then
      echo "✅ K3s service is active on $IP"
      
      # Get more details
      ssh -i ~/.ssh/k3s-key -o StrictHostKeyChecking=no -o ConnectTimeout=10 ubuntu@$IP << 'EOF'
        echo "K3s service status:"
        sudo systemctl status k3s --no-pager -l
        
        echo -e "\nK3s API test:"
        curl -k -s https://localhost:6443/version || echo "Local API not responding"
        
        echo -e "\nK3s nodes:"
        sudo kubectl get nodes --kubeconfig /etc/rancher/k3s/k3s.yaml || echo "kubectl failed"
EOF
    else
      echo "❌ Cannot connect to $IP or K3s not active"
    fi
  fi
done

echo -e "\n🎯 K3s check complete!"