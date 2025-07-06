#!/bin/bash

# Get K3s token from cluster
# Usage: ./get-k3s-token.sh <cluster-ip> <ssh-key-path>

CLUSTER_IP=$1
SSH_KEY=${2:-~/.ssh/aws-key}

if [[ -z "$CLUSTER_IP" ]]; then
    echo "Usage: $0 <cluster-ip> [ssh-key-path]"
    exit 1
fi

echo "🔑 Getting K3s token from cluster: $CLUSTER_IP"

# Get token via SSH
TOKEN=$(ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ubuntu@$CLUSTER_IP "sudo cat /var/lib/rancher/k3s/server/node-token" 2>/dev/null)

if [[ -z "$TOKEN" ]]; then
    echo "❌ Failed to get token from cluster"
    exit 1
fi

echo "✅ Token retrieved successfully"
echo "$TOKEN"