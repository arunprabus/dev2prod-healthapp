#!/bin/bash
set -e

# Update system
apt-get update
apt-get install -y curl wget unzip docker.io

# Install GitHub Actions runner
cd /home/ubuntu
mkdir actions-runner && cd actions-runner

# Download latest runner
curl -o actions-runner-linux-x64-2.311.0.tar.gz -L https://github.com/actions/runner/releases/download/v2.311.0/actions-runner-linux-x64-2.311.0.tar.gz
tar xzf ./actions-runner-linux-x64-2.311.0.tar.gz

# Configure runner
chown -R ubuntu:ubuntu /home/ubuntu/actions-runner

# Get registration token using PAT
REG_TOKEN=$(curl -X POST -H "Authorization: token ${github_token}" -H "Accept: application/vnd.github.v3+json" https://api.github.com/repos/${github_repo}/actions/runners/registration-token | grep -o '"token":"[^"]*' | cut -d'"' -f4)

# Create service
sudo -u ubuntu ./config.sh --url https://github.com/${github_repo} --token $REG_TOKEN --name "aws-runner-$(hostname)" --labels "awsgithubrunner,aws,self-hosted" --unattended

# Install and start service
./svc.sh install ubuntu
./svc.sh start

# Add ubuntu to docker group
usermod -aG docker ubuntu

echo "GitHub runner configured successfully"