#!/bin/bash
set -e

# Basic setup
apt-get update
apt-get install -y curl wget unzip docker.io git jq

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
mv kubectl /usr/local/bin/

# Install AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install

# Setup runner
cd /home/ubuntu
mkdir -p actions-runner && cd actions-runner
curl -o actions-runner-linux-x64-2.311.0.tar.gz -L https://github.com/actions/runner/releases/download/v2.311.0/actions-runner-linux-x64-2.311.0.tar.gz
tar xzf ./actions-runner-linux-x64-2.311.0.tar.gz
chown -R ubuntu:ubuntu /home/ubuntu/actions-runner

# Clean existing runners
EXISTING_RUNNERS=$(curl -s -H "Authorization: token ${github_token}" https://api.github.com/repos/${github_repo}/actions/runners | jq -r '.runners[] | select(.name | contains("github-runner-${network_tier}")) | .id')
for runner_id in $EXISTING_RUNNERS; do
    if [ ! -z "$runner_id" ] && [ "$runner_id" != "null" ]; then
        curl -s -X DELETE -H "Authorization: token ${github_token}" https://api.github.com/repos/${github_repo}/actions/runners/$runner_id
    fi
done
sleep 5

# Get token and configure
REG_TOKEN=$(curl -s -X POST -H "Authorization: token ${github_token}" https://api.github.com/repos/${github_repo}/actions/runners/registration-token | jq -r '.token')
RUNNER_NAME="github-runner-${network_tier}-$(date +%s)"

# Configure and start
sudo -u ubuntu ./config.sh --url https://github.com/${github_repo} --token $REG_TOKEN --name "$RUNNER_NAME" --labels "github-runner-${network_tier}" --unattended --replace
sudo -u ubuntu nohup ./run.sh > /dev/null 2>&1 &

# Add to docker group
usermod -aG docker ubuntu