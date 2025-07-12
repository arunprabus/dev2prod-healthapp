#!/bin/bash
exec > /var/log/user-data.log 2>&1
set -e

echo "=== ROBUST USER DATA STARTED ==="
date

# Function to test connectivity
test_connectivity() {
    echo "Testing connectivity..."
    curl -s --connect-timeout 10 https://api.github.com/zen || {
        echo "ERROR: Cannot reach GitHub API"
        return 1
    }
    echo "GitHub API connectivity: OK"
}

# Function to validate token
validate_token() {
    echo "Validating GitHub token..."
    local response=$(curl -s -H "Authorization: token ${github_token}" https://api.github.com/user)
    if echo "$response" | jq -e '.login' > /dev/null 2>&1; then
        echo "Token validation: OK"
        return 0
    else
        echo "ERROR: Invalid GitHub token"
        echo "Response: $response"
        return 1
    fi
}

# Update system
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y curl wget git jq unzip

# Test connectivity first
test_connectivity || exit 1

# Validate token
validate_token || exit 1

# Create runner directory
mkdir -p /home/ubuntu/actions-runner
cd /home/ubuntu/actions-runner

# Download and extract runner
echo "Downloading GitHub Actions runner..."
curl -o actions-runner-linux-x64-2.311.0.tar.gz -L https://github.com/actions/runner/releases/download/v2.311.0/actions-runner-linux-x64-2.311.0.tar.gz
tar xzf ./actions-runner-linux-x64-2.311.0.tar.gz
chown -R ubuntu:ubuntu /home/ubuntu/actions-runner

# Get registration token with retry
echo "Getting registration token..."
for i in {1..3}; do
    REG_TOKEN=$(curl -s -X POST \
        -H "Authorization: token ${github_token}" \
        -H "Accept: application/vnd.github.v3+json" \
        https://api.github.com/repos/${github_repo}/actions/runners/registration-token | jq -r '.token')
    
    if [[ "$REG_TOKEN" != "null" && "$REG_TOKEN" != "" ]]; then
        echo "Registration token obtained successfully"
        break
    else
        echo "Attempt $i failed, retrying..."
        sleep 5
    fi
done

if [[ "$REG_TOKEN" == "null" || "$REG_TOKEN" == "" ]]; then
    echo "ERROR: Failed to get registration token"
    exit 1
fi

# Configure runner
RUNNER_NAME="github-runner-${network_tier}-$(date +%s)"
LABELS="github-runner-${network_tier}"

echo "Configuring runner: $RUNNER_NAME"
sudo -u ubuntu bash -c "cd /home/ubuntu/actions-runner && ./config.sh --url https://github.com/${github_repo} --token $REG_TOKEN --name '$RUNNER_NAME' --labels '$LABELS' --unattended"

# Install dependencies for runner
./bin/installdependencies.sh

# Install and start service
./svc.sh install ubuntu
./svc.sh start

# Verify service is running
sleep 10
if systemctl is-active --quiet actions.runner.*.service; then
    echo "Runner service is active"
else
    echo "WARNING: Runner service may not be active"
    systemctl status actions.runner.*.service || true
fi

echo "SUCCESS" > /var/log/user-data-complete
echo "=== USER DATA COMPLETED ==="
date