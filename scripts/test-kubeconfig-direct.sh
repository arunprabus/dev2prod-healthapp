#!/bin/bash

# Test kubeconfig directly from existing files
set -e

echo "🧪 Testing cluster connections directly..."

# Test dev environment
if [ -f "/tmp/kubeconfig-dev" ]; then
    echo "Testing Dev Environment..."
    echo "📋 Dev kubeconfig content:"
    cat /tmp/kubeconfig-dev
    echo "---"
    
    export KUBECONFIG=/tmp/kubeconfig-dev
    echo "🔍 Testing connection with verbose output..."
    kubectl get nodes --insecure-skip-tls-verify -v=6 || echo "Connection failed with detailed logs above"
else
    echo "❌ Dev kubeconfig not found"
fi

# Test test environment
if [ -f "/tmp/kubeconfig-test" ]; then
    echo "Testing Test Environment..."
    echo "📋 Test kubeconfig content:"
    cat /tmp/kubeconfig-test
    echo "---"
    
    export KUBECONFIG=/tmp/kubeconfig-test
    echo "🔍 Testing connection with verbose output..."
    kubectl get nodes --insecure-skip-tls-verify -v=6 || echo "Connection failed with detailed logs above"
else
    echo "❌ Test kubeconfig not found"
fi

echo "🎉 Direct testing complete!"