#!/bin/bash
# Check if GitHub Actions runner package includes svc.sh

echo "📦 Checking GitHub Actions runner package contents..."

mkdir -p /tmp/test-runner && cd /tmp/test-runner
curl -O -L https://github.com/actions/runner/releases/download/v2.316.0/actions-runner-linux-x64-2.316.0.tar.gz
tar xzf actions-runner-linux-x64-2.316.0.tar.gz

echo "📋 Package contents:"
ls -la

echo "🔍 Looking for svc.sh:"
if [ -f "svc.sh" ]; then
    echo "✅ svc.sh found in package"
    echo "📄 svc.sh permissions:"
    ls -la svc.sh
else
    echo "❌ svc.sh NOT found in package"
    echo "📁 Available files:"
    find . -name "*.sh" -type f
fi

# Cleanup
cd /tmp && rm -rf test-runner