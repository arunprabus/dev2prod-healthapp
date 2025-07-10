#!/bin/bash
set -e

echo "🚀 Setting up GitHub Runner with custom software..."

# Update system
apt-get update
apt-get install -y curl wget unzip docker.io git jq

# Install Terraform
echo "📦 Installing Terraform..."
wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | tee /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list
apt-get update && apt-get install -y terraform

# Install kubectl
echo "☸️ Installing kubectl..."
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
mv kubectl /usr/local/bin/

# Install AWS CLI v2
echo "☁️ Installing AWS CLI..."
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install

# Install Docker Compose
echo "🐳 Installing Docker Compose..."
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Install Node.js
echo "📦 Installing Node.js..."
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt-get install -y nodejs

# Install Python and pip
echo "🐍 Installing Python tools..."
apt-get install -y python3 python3-pip
pip3 install --upgrade pip

# Install GitHub Actions runner
echo "🏃 Installing GitHub Actions runner..."
cd /home/ubuntu
mkdir actions-runner && cd actions-runner

# Download latest runner
curl -o actions-runner-linux-x64-2.311.0.tar.gz -L https://github.com/actions/runner/releases/download/v2.311.0/actions-runner-linux-x64-2.311.0.tar.gz
tar xzf ./actions-runner-linux-x64-2.311.0.tar.gz

# Configure runner
chown -R ubuntu:ubuntu /home/ubuntu/actions-runner

# Get registration token using PAT
echo "🔐 Registering runner with GitHub..."
echo "Repository: ${github_repo}"

# Test GitHub API access
echo "Testing GitHub API access..."
curl -s -H "Authorization: token ${github_token}" https://api.github.com/repos/${github_repo} > /tmp/api_test.log 2>&1
echo "API test completed"

# Get registration token
echo "Getting registration token..."
REG_TOKEN=$(curl -s -X POST -H "Authorization: token ${github_token}" -H "Accept: application/vnd.github.v3+json" https://api.github.com/repos/${github_repo}/actions/runners/registration-token | grep -o '"token":"[^"]*' | cut -d'"' -f4)
echo "Token obtained, length: $${#REG_TOKEN}"

# Create service with network-specific name
if [ "${network_tier}" = "lower" ]; then
    RUNNER_NAME="awsrunner-lower-devtest-$(hostname | cut -d'-' -f3-)"
    LABELS="awsrunnerlocal,aws-lower,aws-dev,aws-test,self-hosted,terraform,kubectl,docker"
elif [ "${network_tier}" = "higher" ]; then
    RUNNER_NAME="awsrunner-higher-prod-$(hostname | cut -d'-' -f3-)"
    LABELS="awsrunnerlocal,aws-higher,aws-prod,self-hosted,terraform,kubectl,docker"
else
    RUNNER_NAME="awsrunner-${network_tier}-$(hostname | cut -d'-' -f3-)"
    LABELS="awsrunnerlocal,aws-${network_tier},self-hosted,terraform,kubectl,docker"
fi

echo "Configuring runner: $RUNNER_NAME"
echo "Labels: $LABELS"

# Configure runner
sudo -u ubuntu ./config.sh --url https://github.com/${github_repo} --token $REG_TOKEN --name "$RUNNER_NAME" --labels "$LABELS" --unattended > /var/log/runner-config.log 2>&1
CONFIG_EXIT_CODE=$?
echo "Runner configuration exit code: $CONFIG_EXIT_CODE"

# Install and start service
echo "Installing runner service..."
./svc.sh install ubuntu >> /var/log/runner-config.log 2>&1
./svc.sh start >> /var/log/runner-config.log 2>&1

# Add ubuntu to docker group
usermod -aG docker ubuntu

# Test connectivity
echo "🔍 Testing connectivity..."
if ping -c 3 8.8.8.8 > /dev/null 2>&1; then
    echo "✅ Internet connectivity: OK"
else
    echo "❌ Internet connectivity: FAILED"
fi

if curl -s --connect-timeout 10 https://api.github.com/rate_limit > /dev/null; then
    echo "✅ GitHub API connectivity: OK"
else
    echo "❌ GitHub API connectivity: FAILED"
fi

echo "🎉 GitHub runner setup completed!"
echo "Runner name: $RUNNER_NAME"
echo "Public IP: $(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"

# Create simple debug script
echo '#!/bin/bash' > /home/ubuntu/debug-runner.sh
echo 'echo "=== Runner Status ==="' >> /home/ubuntu/debug-runner.sh
echo 'systemctl status actions.runner.* --no-pager' >> /home/ubuntu/debug-runner.sh
echo 'echo "=== Runner Logs ==="' >> /home/ubuntu/debug-runner.sh
echo 'journalctl -u actions.runner.* --no-pager -n 20' >> /home/ubuntu/debug-runner.sh
echo 'echo "=== Config Log ==="' >> /home/ubuntu/debug-runner.sh
echo 'cat /var/log/runner-config.log' >> /home/ubuntu/debug-runner.sh

chmod +x /home/ubuntu/debug-runner.sh
chown ubuntu:ubuntu /home/ubuntu/debug-runner.sh

echo "📋 Debug script: /home/ubuntu/debug-runner.sh"
echo "📋 Config log: /var/log/runner-config.log"