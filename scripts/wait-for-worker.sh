#!/bin/bash

# Wait for worker node to be ready
# Usage: ./wait-for-worker.sh <timeout_minutes>

TIMEOUT=${1:-10}
TIMEOUT_SECONDS=$((TIMEOUT * 60))
ELAPSED=0

echo "⏳ Waiting for worker node to join cluster (timeout: ${TIMEOUT}m)..."

while [ $ELAPSED -lt $TIMEOUT_SECONDS ]; do
    if kubectl get nodes | grep -q "Ready.*worker"; then
        echo "✅ Worker node is ready!"
        kubectl get nodes
        exit 0
    fi
    
    sleep 10
    ELAPSED=$((ELAPSED + 10))
    echo "⏳ Still waiting... (${ELAPSED}s/${TIMEOUT_SECONDS}s)"
done

echo "❌ Timeout: Worker node not ready after ${TIMEOUT} minutes"
kubectl get nodes || true
exit 1