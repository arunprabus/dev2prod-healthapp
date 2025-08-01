#!/bin/bash
set -e

echo "☸️ Installing K3s..."

# Install K3s
curl -sfL https://get.k3s.io | sh -

# Wait for K3s to be ready
echo "⏳ Waiting for K3s to be ready..."
sleep 30

# Check if K3s is running
if systemctl is-active --quiet k3s; then
    echo "✅ K3s installed and running"
    kubectl get nodes
else
    echo "❌ K3s installation failed"
    exit 1
fi