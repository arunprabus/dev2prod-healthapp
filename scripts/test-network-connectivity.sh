#!/bin/bash
set -e

NETWORK_TIER=${1:-lower}

echo "🔍 Testing network connectivity for $NETWORK_TIER environment..."

# Test basic connectivity
echo "Testing basic connectivity..."
curl -s --connect-timeout 5 https://api.github.com/rate_limit > /dev/null && echo "✅ GitHub API accessible" || echo "❌ GitHub API not accessible"

# Test AWS connectivity
echo "Testing AWS connectivity..."
aws sts get-caller-identity > /dev/null && echo "✅ AWS API accessible" || echo "❌ AWS API not accessible"

echo "✅ Network connectivity test completed"