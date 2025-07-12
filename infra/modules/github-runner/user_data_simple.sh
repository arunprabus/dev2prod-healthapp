#!/bin/bash
exec > /var/log/user-data.log 2>&1

echo "=== USER DATA STARTED ==="
date

# Update system
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y curl wget git jq

# Install AWS Systems Manager Agent (proper method)
wget https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/debian_amd64/amazon-ssm-agent.deb
dpkg -i amazon-ssm-agent.deb
systemctl enable amazon-ssm-agent
systemctl start amazon-ssm-agent

# Install kubectl for K8s operations
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
mv kubectl /usr/local/bin/

# Install Docker for container operations
apt-get install -y docker.io
systemctl enable docker
systemctl start docker
usermod -aG docker ubuntu

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

# Configure runner (no validation)
sudo -u ubuntu bash -c "cd /home/ubuntu/actions-runner && ./config.sh --url https://github.com/${github_repo} --token $REG_TOKEN --name '$RUNNER_NAME' --labels '$LABELS' --unattended --replace"

# Install and start service
./svc.sh install ubuntu
./svc.sh start

echo "SUCCESS" > /var/log/user-data-complete
echo "=== USER DATA COMPLETED ==="
date