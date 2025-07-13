#!/bin/bash

# Simple Kubeconfig Fix Script
# This script creates the base64 value that you can manually copy to GitHub secrets

set -e

echo "🔧 Simple kubeconfig fix for GitHub secrets..."

# Check if kubeconfig file exists
if [ ! -f "kubeconfig-lower.yaml" ]; then
    echo "❌ kubeconfig-lower.yaml not found"
    echo "Available kubeconfig files:"
    ls -la kubeconfig*.yaml 2>/dev/null || echo "No kubeconfig files found"
    exit 1
fi

echo "✅ Found kubeconfig-lower.yaml"

# Test the kubeconfig locally
export KUBECONFIG="$PWD/kubeconfig-lower.yaml"
echo "🧪 Testing kubeconfig connection..."

if timeout 30 kubectl cluster-info --request-timeout=10s 2>/dev/null; then
    echo "✅ Kubeconfig is working!"
    kubectl get nodes 2>/dev/null || echo "Nodes not accessible (normal from different network)"
else
    echo "⚠️ Connection test failed (normal from GitHub Actions)"
fi

# Create base64 encoded version
echo ""
echo "📦 Creating base64 encoded version..."
KUBECONFIG_B64=$(base64 -w 0 kubeconfig-lower.yaml)

echo ""
echo "🎯 COPY THIS VALUE TO GITHUB SECRETS:"
echo ""
echo "=================================================="
echo "Secret Names: KUBECONFIG_DEV and KUBECONFIG_TEST"
echo "=================================================="
echo ""
echo "$KUBECONFIG_B64"
echo ""
echo "=================================================="
echo ""
echo "📋 Manual Steps:"
echo "1. Copy the base64 value above"
echo "2. Go to GitHub → Settings → Secrets and variables → Actions"
echo "3. Create or update these secrets:"
echo "   - KUBECONFIG_DEV (paste the value)"
echo "   - KUBECONFIG_TEST (paste the same value)"
echo ""
echo "🧪 After updating secrets, test with:"
echo "   Actions → Kubeconfig Access → environment: dev → action: test-connection"
echo ""
echo "✅ Kubeconfig fix completed!"