#!/bin/bash
exec > /var/log/user-data.log 2>&1
set -e

echo "=== USER DATA STARTED ==="
date

# Update system (non-interactive)
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y curl wget git jq

# Create runner directory
mkdir -p /home/ubuntu/actions-runner
cd /home/ubuntu/actions-runner

# Download runner
curl -o actions-runner-linux-x64-2.311.0.tar.gz -L https://github.com/actions/runner/releases/download/v2.311.0/actions-runner-linux-x64-2.311.0.tar.gz
tar xzf ./actions-runner-linux-x64-2.311.0.tar.gz
chown -R ubuntu:ubuntu /home/ubuntu/actions-runner

# Get registration token
REG_TOKEN=$(curl -s -X POST -H "Authorization: token ${github_token}" -H "Accept: application/vnd.github.v3+json" https://api.github.com/repos/${github_repo}/actions/runners/registration-token | jq -r '.token')
RUNNER_NAME="github-runner-${network_tier}-$(date +%s)"
LABELS="github-runner-${network_tier}"

# Configure runner
sudo -u ubuntu bash -c "cd /home/ubuntu/actions-runner && ./config.sh --url https://github.com/${github_repo} --token $REG_TOKEN --name '$RUNNER_NAME' --labels '$LABELS' --unattended"

# Install and start service
./svc.sh install ubuntu
./svc.sh start

echo "SUCCESS" > /var/log/user-data-complete
echo "=== USER DATA COMPLETED ==="
date