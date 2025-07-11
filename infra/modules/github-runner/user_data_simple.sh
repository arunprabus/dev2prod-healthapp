#!/bin/bash
exec > /var/log/user-data.log 2>&1
set -x

echo "=== USER DATA STARTED ==="
date
whoami
pwd

# Basic test
echo "Creating test file..."
touch /tmp/user-data-test
echo "Test file created: $(ls -la /tmp/user-data-test)"

# Update system
echo "Updating system..."
apt-get update
apt-get install -y curl wget git jq

# Create runner directory
echo "Creating runner directory..."
mkdir -p /home/ubuntu/actions-runner
chown ubuntu:ubuntu /home/ubuntu/actions-runner
echo "Directory created: $(ls -la /home/ubuntu/)"

# Download runner
echo "Downloading GitHub runner..."
cd /home/ubuntu/actions-runner
curl -o actions-runner-linux-x64-2.311.0.tar.gz -L https://github.com/actions/runner/releases/download/v2.311.0/actions-runner-linux-x64-2.311.0.tar.gz
tar xzf ./actions-runner-linux-x64-2.311.0.tar.gz
chown -R ubuntu:ubuntu /home/ubuntu/actions-runner

# Get registration token
echo "Getting registration token..."
REG_TOKEN=$(curl -s -X POST -H "Authorization: token ${github_token}" -H "Accept: application/vnd.github.v3+json" https://api.github.com/repos/${github_repo}/actions/runners/registration-token | jq -r '.token')
RUNNER_NAME="github-runner-${network_tier}-$(hostname | cut -d'-' -f3-)"
LABELS="github-runner-${network_tier}"

echo "Configuring runner: $RUNNER_NAME"
sudo -u ubuntu bash -c "cd /home/ubuntu/actions-runner && ./config.sh --url https://github.com/${github_repo} --token $REG_TOKEN --name '$RUNNER_NAME' --labels '$LABELS' --unattended"

# Install and start service
echo "Installing service..."
cd /home/ubuntu/actions-runner
./svc.sh install ubuntu
./svc.sh start

echo "=== USER DATA COMPLETED ==="
date
echo "SUCCESS" > /var/log/user-data-complete