#!/bin/bash
set -e

echo "🚀 Setting up GitHub Runner..."

# Update system and install basics
apt-get update
apt-get install -y curl wget unzip git jq docker.io

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl && mv kubectl /usr/local/bin/

# Setup GitHub Actions runner
cd /home/ubuntu
mkdir -p actions-runner && cd actions-runner
curl -o actions-runner-linux-x64-2.311.0.tar.gz -L https://github.com/actions/runner/releases/download/v2.311.0/actions-runner-linux-x64-2.311.0.tar.gz
tar xzf ./actions-runner-linux-x64-2.311.0.tar.gz
chown -R ubuntu:ubuntu /home/ubuntu/actions-runner

# Clean up old runners
echo "🧹 Cleaning up old runners..."
ALL_RUNNERS=$(curl -s -H "Authorization: token ${github_token}" -H "Accept: application/vnd.github.v3+json" https://api.github.com/repos/${github_repo}/actions/runners | jq -r ".runners[] | select(.name | contains(\"github-runner-${network_tier}\")) | .id")
for runner_id in $ALL_RUNNERS; do
    if [ ! -z "$runner_id" ] && [ "$runner_id" != "null" ]; then
        curl -s -X DELETE -H "Authorization: token ${github_token}" -H "Accept: application/vnd.github.v3+json" https://api.github.com/repos/${github_repo}/actions/runners/$runner_id
        sleep 2
    fi
done

# Register runner
REG_TOKEN=$(curl -s -X POST -H "Authorization: token ${github_token}" -H "Accept: application/vnd.github.v3+json" https://api.github.com/repos/${github_repo}/actions/runners/registration-token | jq -r '.token')
RUNNER_NAME="github-runner-${network_tier}-$(hostname | cut -d'-' -f3-)"
LABELS="github-runner-${network_tier}"

echo "🚀 Configuring runner: $RUNNER_NAME"
sudo -u ubuntu bash -c "cd /home/ubuntu/actions-runner && ./config.sh --url https://github.com/${github_repo} --token $REG_TOKEN --name '$RUNNER_NAME' --labels '$LABELS' --unattended"

# Install and start service
./svc.sh install ubuntu
./svc.sh start

# Add ubuntu to docker group
usermod -aG docker ubuntu

echo "✅ GitHub runner setup completed!"
echo "Runner name: $RUNNER_NAME"
echo "Labels: $LABELS"