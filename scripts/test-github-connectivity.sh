#!/bin/bash

echo "🔍 Testing GitHub connectivity for runner..."

# Test basic internet connectivity
echo "1. Testing basic internet connectivity..."
if ping -c 3 8.8.8.8 > /dev/null 2>&1; then
    echo "✅ Internet connectivity: OK"
else
    echo "❌ Internet connectivity: FAILED"
    exit 1
fi

# Test DNS resolution
echo "2. Testing DNS resolution..."
if nslookup github.com > /dev/null 2>&1; then
    echo "✅ DNS resolution: OK"
else
    echo "❌ DNS resolution: FAILED"
    exit 1
fi

# Test HTTPS connectivity to GitHub
echo "3. Testing HTTPS connectivity to GitHub..."
if curl -s --connect-timeout 10 https://github.com > /dev/null; then
    echo "✅ GitHub HTTPS: OK"
else
    echo "❌ GitHub HTTPS: FAILED"
    exit 1
fi

# Test GitHub API
echo "4. Testing GitHub API..."
if curl -s --connect-timeout 10 https://api.github.com/rate_limit > /dev/null; then
    echo "✅ GitHub API: OK"
else
    echo "❌ GitHub API: FAILED"
    exit 1
fi

# Test runner registration endpoint
echo "5. Testing runner registration endpoint..."
if curl -s --connect-timeout 10 https://api.github.com/repos/arunprabus/dev2prod-healthapp/actions/runners > /dev/null; then
    echo "✅ Runner registration endpoint: OK"
else
    echo "❌ Runner registration endpoint: FAILED"
    exit 1
fi

echo "🎉 All GitHub connectivity tests passed!"