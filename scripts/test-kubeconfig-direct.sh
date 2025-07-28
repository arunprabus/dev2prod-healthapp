#!/bin/bash

# Test kubeconfig directly from existing files
set -e

echo "🧪 Testing cluster connections directly..."

# Test dev environment
if [ -f "/tmp/kubeconfig-dev" ]; then
    echo "Testing Dev Environment..."
    export KUBECONFIG=/tmp/kubeconfig-dev
    if timeout 30 kubectl get nodes --request-timeout=20s > /dev/null 2>&1; then
        echo "✅ Dev cluster connection successful"
        kubectl get nodes
    else
        echo "❌ Dev cluster connection failed"
    fi
else
    echo "❌ Dev kubeconfig not found"
fi

# Test test environment
if [ -f "/tmp/kubeconfig-test" ]; then
    echo "Testing Test Environment..."
    export KUBECONFIG=/tmp/kubeconfig-test
    if timeout 30 kubectl get nodes --request-timeout=20s > /dev/null 2>&1; then
        echo "✅ Test cluster connection successful"
        kubectl get nodes
    else
        echo "❌ Test cluster connection failed"
    fi
else
    echo "❌ Test kubeconfig not found"
fi

echo "🎉 Direct testing complete!"