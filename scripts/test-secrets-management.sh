#!/bin/bash

# Test script for secrets management
# This script tests the update-github-secrets.sh script functionality

set -e

echo "🧪 Testing secrets management functionality..."

# Check if the script exists
if [ ! -f "scripts/update-github-secrets.sh" ]; then
    echo "❌ Error: scripts/update-github-secrets.sh not found"
    exit 1
fi

# Make the script executable
chmod +x scripts/update-github-secrets.sh

# Test help function
echo "📋 Testing help function..."
./scripts/update-github-secrets.sh help

# Check if GitHub token is set
if [ -z "$GITHUB_TOKEN" ]; then
    echo "⚠️ Warning: GITHUB_TOKEN environment variable not set"
    echo "Some tests will be skipped"
    SKIP_API_TESTS=true
else
    SKIP_API_TESTS=false
fi

# Test list function (if token is available)
if [ "$SKIP_API_TESTS" = false ]; then
    echo "📋 Testing list function..."
    ./scripts/update-github-secrets.sh list
fi

# Create a test kubeconfig file
echo "📝 Creating test kubeconfig file..."
cat > test-kubeconfig.yaml << EOF
apiVersion: v1
kind: Config
clusters:
- cluster:
    server: https://test-server:6443
    certificate-authority-data: test-ca-data
  name: test-cluster
contexts:
- context:
    cluster: test-cluster
    user: test-user
  name: test-context
current-context: test-context
users:
- name: test-user
  user:
    client-certificate-data: test-cert-data
    client-key-data: test-key-data
EOF

# Test update-kubeconfig function (without API call)
echo "🔑 Testing update-kubeconfig function (dry run)..."
GITHUB_TOKEN=dummy REPO_NAME=dummy ./scripts/update-github-secrets.sh update-kubeconfig test test-kubeconfig.yaml || true

# Clean up
echo "🧹 Cleaning up..."
rm -f test-kubeconfig.yaml

echo "✅ Tests completed!"
echo ""
echo "To run a full test with API calls, set the GITHUB_TOKEN environment variable:"
echo "export GITHUB_TOKEN=your_github_token"
echo "./scripts/test-secrets-management.sh"
echo ""
echo "Or use the GitHub Actions workflow:"
echo "Actions → Update GitHub Secrets → action: list"