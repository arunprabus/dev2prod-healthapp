#!/bin/bash

echo "🔍 Checking K3s installation logs via SSH..."

K3S_IP="13.201.224.224"

# Setup SSH key
mkdir -p ~/.ssh
echo "$SSH_PRIVATE_KEY" > ~/.ssh/k3s-key
chmod 600 ~/.ssh/k3s-key

echo "📋 Checking user-data logs..."
ssh -i ~/.ssh/k3s-key -o ConnectTimeout=10 -o StrictHostKeyChecking=no ubuntu@$K3S_IP "sudo tail -50 /var/log/cloud-init-output.log"

echo ""
echo "📋 Checking K3s install log..."
ssh -i ~/.ssh/k3s-key -o ConnectTimeout=10 -o StrictHostKeyChecking=no ubuntu@$K3S_IP "sudo cat /var/log/k3s-install.log 2>/dev/null || echo 'No K3s install log found'"

echo ""
echo "📋 Checking K3s service status..."
ssh -i ~/.ssh/k3s-key -o ConnectTimeout=10 -o StrictHostKeyChecking=no ubuntu@$K3S_IP "sudo systemctl status k3s --no-pager || echo 'K3s service not found'"

echo ""
echo "📋 Checking if K3s binary exists..."
ssh -i ~/.ssh/k3s-key -o ConnectTimeout=10 -o StrictHostKeyChecking=no ubuntu@$K3S_IP "which k3s || echo 'K3s binary not found'"

echo ""
echo "📋 Checking kubeconfig file..."
ssh -i ~/.ssh/k3s-key -o ConnectTimeout=10 -o StrictHostKeyChecking=no ubuntu@$K3S_IP "sudo ls -la /etc/rancher/k3s/ 2>/dev/null || echo 'K3s config directory not found'"

rm -f ~/.ssh/k3s-key