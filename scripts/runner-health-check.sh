#!/bin/bash
# GitHub Runner Health Check
# Usage: ./runner-health-check.sh [runner_ip]

RUNNER_IP="${1:-$(terraform -chdir=infra/two-network-setup output -raw github_runner_public_ip 2>/dev/null)}"

if [[ -z "$RUNNER_IP" || "$RUNNER_IP" == "Not available" ]]; then
    echo "❌ Runner IP not available"
    exit 1
fi

echo "🔍 Checking GitHub Runner health: $RUNNER_IP"

# Test SSH connectivity
if timeout 10 ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no ubuntu@$RUNNER_IP "echo 'SSH OK'" 2>/dev/null; then
    echo "✅ SSH connectivity: OK"
else
    echo "❌ SSH connectivity: FAILED"
    exit 1
fi

# Check runner service status
echo "🔍 Checking runner service..."
ssh -o StrictHostKeyChecking=no ubuntu@$RUNNER_IP "
    echo '=== Runner Service Status ==='
    systemctl is-active actions.runner.* 2>/dev/null || echo 'Service not found'
    
    echo '=== Recent Logs ==='
    journalctl -u actions.runner.* --no-pager -n 5 2>/dev/null || echo 'No logs available'
    
    echo '=== Connectivity Tests ==='
    if ping -c 2 8.8.8.8 >/dev/null 2>&1; then
        echo '✅ Internet: OK'
    else
        echo '❌ Internet: FAILED'
    fi
    
    if curl -s --connect-timeout 5 https://api.github.com/rate_limit >/dev/null; then
        echo '✅ GitHub API: OK'
    else
        echo '❌ GitHub API: FAILED'
    fi
    
    echo '=== Software Versions ==='
    terraform version | head -1
    kubectl version --client --short 2>/dev/null || echo 'kubectl: Not available'
    aws --version
    docker --version
"

echo "✅ Health check completed"