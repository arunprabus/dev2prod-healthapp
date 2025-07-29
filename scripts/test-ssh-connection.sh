#!/bin/bash

echo "🔧 Testing SSH connections to K3s clusters..."

CLUSTERS=("13.232.75.155" "13.127.158.59")
NAMES=("dev" "test")

for i in "${!CLUSTERS[@]}"; do
  IP="${CLUSTERS[$i]}"
  NAME="${NAMES[$i]}"
  
  echo "📡 Testing SSH to $NAME cluster ($IP)..."
  
  # Test SSH connection
  if ssh -i ~/.ssh/k3s-key -o StrictHostKeyChecking=no -o ConnectTimeout=10 ubuntu@$IP 'echo "SSH connection successful"' 2>/dev/null; then
    echo "✅ SSH to $NAME cluster working"
    
    # Check K3s status
    echo "Checking K3s status on $NAME cluster..."
    ssh -i ~/.ssh/k3s-key -o StrictHostKeyChecking=no ubuntu@$IP << EOF
      echo "=== K3s Service Status ==="
      sudo systemctl status k3s --no-pager -l
      
      echo -e "\n=== K3s API Test ==="
      curl -k -s https://localhost:6443/version || echo "API not responding"
      
      echo -e "\n=== K3s Nodes ==="
      sudo kubectl get nodes --kubeconfig /etc/rancher/k3s/k3s.yaml || echo "kubectl failed"
      
      echo -e "\n=== System Resources ==="
      free -h
      df -h /
EOF
  else
    echo "❌ SSH to $NAME cluster failed"
    
    # Test if port is open
    if timeout 5 bash -c "</dev/tcp/$IP/22" 2>/dev/null; then
      echo "✅ Port 22 is open on $IP"
    else
      echo "❌ Port 22 is closed on $IP"
    fi
  fi
  
  echo "----------------------------------------"
done

echo "🎯 SSH connection test complete!"