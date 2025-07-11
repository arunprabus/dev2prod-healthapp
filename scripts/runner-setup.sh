#!/bin/bash
set -e

GITHUB_TOKEN="$1"
GITHUB_REPO="$2"
NETWORK_TIER="$3"

echo "🚀 Full GitHub Runner Setup..."

# Install software
apt-get install -y docker.io terraform
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl && mv kubectl /usr/local/bin/
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip && ./aws/install

# Setup GitHub Actions runner
cd /home/ubuntu
mkdir -p actions-runner && cd actions-runner
curl -o actions-runner-linux-x64-2.311.0.tar.gz -L https://github.com/actions/runner/releases/download/v2.311.0/actions-runner-linux-x64-2.311.0.tar.gz
tar xzf ./actions-runner-linux-x64-2.311.0.tar.gz
chown -R ubuntu:ubuntu /home/ubuntu/actions-runner

# Clean up old runners
echo "🧹 Cleaning up old runners..."
ALL_RUNNERS=$(curl -s -H "Authorization: token $GITHUB_TOKEN" -H "Accept: application/vnd.github.v3+json" https://api.github.com/repos/$GITHUB_REPO/actions/runners | jq -r ".runners[] | select(.name | contains(\"github-runner-$NETWORK_TIER\")) | .id")
for runner_id in $ALL_RUNNERS; do
    if [ ! -z "$runner_id" ] && [ "$runner_id" != "null" ]; then
        curl -s -X DELETE -H "Authorization: token $GITHUB_TOKEN" -H "Accept: application/vnd.github.v3+json" https://api.github.com/repos/$GITHUB_REPO/actions/runners/$runner_id
        sleep 2
    fi
done

# Register runner
REG_TOKEN=$(curl -s -X POST -H "Authorization: token $GITHUB_TOKEN" -H "Accept: application/vnd.github.v3+json" https://api.github.com/repos/$GITHUB_REPO/actions/runners/registration-token | jq -r '.token')
RUNNER_NAME="github-runner-$NETWORK_TIER-$(hostname | cut -d'-' -f3-)"
LABELS="github-runner-$NETWORK_TIER"

sudo -u ubuntu bash -c "cd /home/ubuntu/actions-runner && ./config.sh --url https://github.com/$GITHUB_REPO --token $REG_TOKEN --name '$RUNNER_NAME' --labels '$LABELS' --unattended"

# Install and start service
./svc.sh install ubuntu
./svc.sh start

usermod -aG docker ubuntu
echo "✅ Runner setup completed!"