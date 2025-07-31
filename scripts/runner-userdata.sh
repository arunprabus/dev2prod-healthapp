#!/bin/bash

# GitHub Runner Installation Script
# This script runs during EC2 instance boot to install and configure GitHub Actions runner

set -e

# Variables (these will be replaced by Terraform)
GITHUB_REPO="${github_repo}"
GITHUB_PAT="${github_pat}"
RUNNER_NAME="${runner_name}"

# Update system
apt-get update -y

# Install required packages
apt-get install -y curl jq unzip

# Create runner user
useradd -m -s /bin/bash runner
usermod -aG sudo runner
echo "runner ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Create actions-runner directory
mkdir -p /home/ubuntu/actions-runner
cd /home/ubuntu/actions-runner

# Download GitHub Actions runner
RUNNER_VERSION=$(curl -s https://api.github.com/repos/actions/runner/releases/latest | jq -r '.tag_name' | sed 's/v//')
curl -o actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz -L https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz

# Extract runner
tar xzf ./actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz
rm actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz

# Set permissions
chown -R ubuntu:ubuntu /home/ubuntu/actions-runner
chmod +x /home/ubuntu/actions-runner/config.sh
chmod +x /home/ubuntu/actions-runner/run.sh

# Get registration token
REGISTRATION_TOKEN=$(curl -s -X POST \
  -H "Authorization: token $GITHUB_PAT" \
  -H "Accept: application/vnd.github.v3+json" \
  "https://api.github.com/repos/$GITHUB_REPO/actions/runners/registration-token" | \
  jq -r '.token')

# Configure runner as ubuntu user
sudo -u ubuntu ./config.sh \
  --url "https://github.com/$GITHUB_REPO" \
  --token "$REGISTRATION_TOKEN" \
  --name "$RUNNER_NAME" \
  --work "_work" \
  --replace \
  --unattended

# Install and start as service
./svc.sh install
./svc.sh start

# Enable service to start on boot
systemctl enable actions.runner.*.service

echo "GitHub Actions runner installed and started successfully"