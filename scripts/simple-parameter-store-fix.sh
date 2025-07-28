#!/bin/bash

# Simple Parameter Store Fix using existing kubeconfig
set -e

echo "🔧 Setting up Parameter Store from existing kubeconfig..."

# Dev environment
if [ -f "/tmp/kubeconfig-dev" ]; then
    echo "📋 Processing dev kubeconfig..."
    
    # Extract server and token from kubeconfig
    SERVER=$(grep "server:" /tmp/kubeconfig-dev | awk '{print $2}')
    TOKEN=$(grep "token:" /tmp/kubeconfig-dev | awk '{print $2}')
    
    if [ -n "$SERVER" ] && [ -n "$TOKEN" ]; then
        echo "✅ Dev kubeconfig data extracted"
        echo "Server: $SERVER"
        echo "Token: ${TOKEN:0:20}..."
        
        # Store in environment for GitHub Actions to use
        echo "DEV_SERVER=$SERVER" >> $GITHUB_ENV
        echo "DEV_TOKEN=$TOKEN" >> $GITHUB_ENV
        echo "✅ Dev environment configured"
    fi
fi

# Test environment  
if [ -f "/tmp/kubeconfig-test" ]; then
    echo "📋 Processing test kubeconfig..."
    
    SERVER=$(grep "server:" /tmp/kubeconfig-test | awk '{print $2}')
    TOKEN=$(grep "token:" /tmp/kubeconfig-test | awk '{print $2}')
    
    if [ -n "$SERVER" ] && [ -n "$TOKEN" ]; then
        echo "✅ Test kubeconfig data extracted"
        echo "Server: $SERVER"
        echo "Token: ${TOKEN:0:20}..."
        
        echo "TEST_SERVER=$SERVER" >> $GITHUB_ENV
        echo "TEST_TOKEN=$TOKEN" >> $GITHUB_ENV
        echo "✅ Test environment configured"
    fi
fi

echo "🎉 Parameter Store simulation complete!"
echo "Use the extracted credentials for cluster access."