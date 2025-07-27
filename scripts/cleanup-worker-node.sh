#!/bin/bash

# Cleanup K3s Worker Node
# Usage: ./cleanup-worker-node.sh <worker_id>

set -e

WORKER_ID=$1

if [ -z "$WORKER_ID" ]; then
    echo "Usage: $0 <worker_id>"
    exit 1
fi

echo "🧹 Cleaning up worker node: $WORKER_ID"

# Drain node from cluster
WORKER_IP=$(aws ec2 describe-instances \
    --instance-ids $WORKER_ID \
    --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)

if [ "$WORKER_IP" != "None" ]; then
    NODE_NAME=$(ssh -o StrictHostKeyChecking=no ubuntu@$WORKER_IP "hostname")
    kubectl drain $NODE_NAME --ignore-daemonsets --delete-emptydir-data --force || true
    kubectl delete node $NODE_NAME || true
fi

# Terminate instance
aws ec2 terminate-instances --instance-ids $WORKER_ID
echo "✅ Worker node $WORKER_ID terminated"