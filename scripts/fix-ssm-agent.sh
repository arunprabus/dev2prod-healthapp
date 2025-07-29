#!/bin/bash

# Fix SSM Agent on K3s instances
echo "🔧 Fixing SSM Agent..."

INSTANCES=("13.232.75.155" "13.127.158.59")

for IP in "${INSTANCES[@]}"; do
  echo "📡 Fixing SSM on $IP..."
  
  ssh -i ~/.ssh/k3s-key -o StrictHostKeyChecking=no ubuntu@$IP << 'EOF'
    # Install SSM Agent
    sudo snap install amazon-ssm-agent --classic
    sudo systemctl enable snap.amazon-ssm-agent.amazon-ssm-agent.service
    sudo systemctl start snap.amazon-ssm-agent.amazon-ssm-agent.service
    
    # Check status
    sudo systemctl status snap.amazon-ssm-agent.amazon-ssm-agent.service --no-pager
    
    # Check K3s while we're here
    sudo systemctl status k3s --no-pager
    curl -k https://localhost:6443/version || echo "K3s API not responding"
EOF
  
  echo "✅ SSM fix attempted on $IP"
done

echo "🎉 SSM Agent fix complete!"