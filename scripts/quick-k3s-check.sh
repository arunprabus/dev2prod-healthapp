#!/bin/bash

echo "🔍 Quick K3s diagnostic..."

CLUSTERS=("13.232.75.155" "13.127.158.59")
NAMES=("dev" "test")

for i in "${!CLUSTERS[@]}"; do
  IP="${CLUSTERS[$i]}"
  NAME="${NAMES[$i]}"
  
  echo "📡 Checking $NAME cluster ($IP)..."
  
  # Quick SSH commands with timeout
  ssh -i ~/.ssh/k3s-key -o StrictHostKeyChecking=no -o ConnectTimeout=5 ubuntu@$IP 'echo "Connected to '$NAME'"'
  
  echo "K3s service status:"
  ssh -i ~/.ssh/k3s-key -o StrictHostKeyChecking=no -o ConnectTimeout=5 ubuntu@$IP 'sudo systemctl is-active k3s'
  
  echo "API test with timeout:"
  ssh -i ~/.ssh/k3s-key -o StrictHostKeyChecking=no -o ConnectTimeout=5 ubuntu@$IP 'timeout 5 curl -k -s https://localhost:6443/version || echo "API timeout/failed"'
  
  echo "Process check:"
  ssh -i ~/.ssh/k3s-key -o StrictHostKeyChecking=no -o ConnectTimeout=5 ubuntu@$IP 'ps aux | grep k3s | head -2'
  
  echo "Memory usage:"
  ssh -i ~/.ssh/k3s-key -o StrictHostKeyChecking=no -o ConnectTimeout=5 ubuntu@$IP 'free -h | head -2'
  
  echo "----------------------------------------"
done

echo "🎯 Quick diagnostic complete!"