#!/bin/bash

# Fix Kubeconfig GitHub Secret
# This script creates the proper GitHub secret for kubeconfig access

set -e

echo "🔧 Fixing kubeconfig GitHub secret..."

# Check if kubeconfig file exists
if [ ! -f "kubeconfig-lower.yaml" ]; then
    echo "❌ Error: kubeconfig-lower.yaml not found"
    echo "Please ensure the kubeconfig file exists in the current directory"
    exit 1
fi

# Validate kubeconfig content
if [ ! -s "kubeconfig-lower.yaml" ]; then
    echo "❌ Error: kubeconfig-lower.yaml is empty"
    exit 1
fi

echo "📁 Found kubeconfig file: kubeconfig-lower.yaml"

# Test kubeconfig locally (optional)
echo "🧪 Testing kubeconfig locally..."
export KUBECONFIG="$PWD/kubeconfig-lower.yaml"

if timeout 10 kubectl cluster-info --request-timeout=5s > /dev/null 2>&1; then
    echo "✅ Kubeconfig is valid and cluster is reachable"
    kubectl get nodes
else
    echo "⚠️  Warning: Could not connect to cluster (this is normal if running from different network)"
    echo "   The kubeconfig will still be uploaded to GitHub secrets"
fi

# Create base64 encoded version for GitHub secret
echo "🔐 Creating base64 encoded version for GitHub secret..."
BASE64_KUBECONFIG=$(base64 -w 0 kubeconfig-lower.yaml)

echo ""
echo "✅ Kubeconfig processed successfully!"
echo ""
echo "📋 Next steps:"
echo "1. Go to GitHub repository Settings → Secrets and variables → Actions"
echo "2. Create or update these secrets:"
echo ""
echo "   Secret Name: KUBECONFIG_DEV"
echo "   Secret Value: (copy the base64 string below)"
echo ""
echo "   Secret Name: KUBECONFIG_TEST" 
echo "   Secret Value: (copy the same base64 string below)"
echo ""
echo "--- BASE64 KUBECONFIG START ---"
echo "$BASE64_KUBECONFIG"
echo "--- BASE64 KUBECONFIG END ---"
echo ""
echo "3. After updating the secrets, test with:"
echo "   Actions → Kubeconfig Access → environment: dev → action: test-connection"
echo ""
echo "💡 Tip: The same kubeconfig works for both dev and test environments"
echo "    since they're on the same 'lower' network cluster"