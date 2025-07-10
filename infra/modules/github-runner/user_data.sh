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

# Install Node.js (for frontend builds)
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
echo "Testing GitHub API access..."

# Test API access first
API_RESPONSE=$(curl -s -w "HTTP_CODE:%{http_code}" -H "Authorization: token ${github_token}" -H "Accept: application/vnd.github.v3+json" https://api.github.com/repos/${github_repo})
echo "API Test Response: $API_RESPONSE"

# Get registration token with full logging
echo "Getting registration token..."
TOKEN_RESPONSE=$(curl -s -w "HTTP_CODE:%{http_code}" -X POST -H "Authorization: token ${github_token}" -H "Accept: application/vnd.github.v3+json" https://api.github.com/repos/${github_repo}/actions/runners/registration-token)
echo "Token Response: $TOKEN_RESPONSE"

REG_TOKEN=$(echo "$TOKEN_RESPONSE" | grep -o '"token":"[^"]*' | cut -d'"' -f4)
echo "Extracted Token Length: ${#REG_TOKEN}"

# Create service with network-specific name
if [ "${network_tier}" = "lower" ]; then
    RUNNER_NAME="awsrunner-lower-devtest-$(hostname | cut -d'-' -f3-)"
    LABELS="awsrunnerlocal,aws-lower,aws-dev,aws-test,self-hosted,terraform,kubectl,docker"
elif [ "${network_tier}" = "higher" ]; then
    RUNNER_NAME="awsrunner-higher-prod-$(hostname | cut -d'-' -f3-)"
    LABELS="awsrunnerlocal,aws-higher,aws-prod,self-hosted,terraform,kubectl,docker"
elif [ "${network_tier}" = "monitoring" ]; then
    RUNNER_NAME="awsrunner-monitoring-$(hostname | cut -d'-' -f3-)"
    LABELS="awsrunnerlocal,aws-monitoring,aws-dev,aws-test,aws-prod,self-hosted,terraform,kubectl,docker"
else
    RUNNER_NAME="awsrunner-${network_tier}-$(hostname | cut -d'-' -f3-)"
    LABELS="awsrunnerlocal,aws-${network_tier},self-hosted,terraform,kubectl,docker"
fi

echo "Configuring runner with:"
echo "- Name: $RUNNER_NAME"
echo "- Labels: $LABELS"
echo "- URL: https://github.com/${github_repo}"
echo "- Token present: $([ -n "$REG_TOKEN" ] && echo 'YES' || echo 'NO')"

# Configure runner with detailed logging
sudo -u ubuntu ./config.sh --url https://github.com/${github_repo} --token $REG_TOKEN --name "$RUNNER_NAME" --labels "$LABELS" --unattended 2>&1 | tee /var/log/runner-config.log
CONFIG_EXIT_CODE=$?
echo "Runner configuration exit code: $CONFIG_EXIT_CODE"

# Install and start service with logging
echo "Installing runner service..."
./svc.sh install ubuntu 2>&1 | tee -a /var/log/runner-config.log
SVC_INSTALL_EXIT_CODE=$?
echo "Service install exit code: $SVC_INSTALL_EXIT_CODE"

echo "Starting runner service..."
./svc.sh start 2>&1 | tee -a /var/log/runner-config.log
SVC_START_EXIT_CODE=$?
echo "Service start exit code: $SVC_START_EXIT_CODE"

# Wait and check service status
sleep 10
echo "Checking service status..."
systemctl status actions.runner.* --no-pager 2>&1 | tee -a /var/log/runner-config.log

# Add ubuntu to docker group
usermod -aG docker ubuntu

# Setup kubeconfig access to K3s cluster
echo "☸️ Setting up kubeconfig access..."
mkdir -p /home/ubuntu/.kube
chown ubuntu:ubuntu /home/ubuntu/.kube

# Create script to get kubeconfig from K3s cluster
cat > /home/ubuntu/get-kubeconfig.sh << 'EOF'
#!/bin/bash
# Get kubeconfig from K3s cluster in same network
K3S_IP=$(aws ec2 describe-instances --region ap-south-1 \
  --filters "Name=tag:Name,Values=*k3s-node" "Name=instance-state-name,Values=running" \
  --query "Reservations[].Instances[0].PrivateIpAddress" --output text)

if [ "\$K3S_IP" != "None" ] && [ -n "\$K3S_IP" ]; then
  echo "Found K3s cluster at: \$K3S_IP"
  # Direct access via private IP (same VPC)
  kubectl --server=https://\$K3S_IP:6443 --insecure-skip-tls-verify get nodes
else
  echo "K3s cluster not found or not running"
fi
EOF

chmod +x /home/ubuntu/get-kubeconfig.sh
chown ubuntu:ubuntu /home/ubuntu/get-kubeconfig.sh

# Create helpful aliases
echo "📝 Setting up aliases..."
cat >> /home/ubuntu/.bashrc << 'EOF'
alias k='kubectl'
alias tf='terraform'
alias dc='docker-compose'
alias ll='ls -la'
alias k3s-connect='/home/ubuntu/get-kubeconfig.sh'
alias debug-runner='/home/ubuntu/debug-runner.sh'
alias runner-logs='journalctl -u actions.runner.* -f'
alias runner-status='systemctl status actions.runner.*'
EOF

# Verify installations
echo "✅ Verifying installations..."
terraform version
kubectl version --client
aws --version
docker --version
docker-compose --version
node --version
python3 --version

# Test GitHub connectivity
echo "🔍 Testing GitHub connectivity..."
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

# Final status check
echo "🎉 GitHub runner setup completed!"
echo "Runner name: $RUNNER_NAME"
echo "Labels: $LABELS"
echo "Public IP: $(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"
echo "Private IP: $(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)"

# Create debugging script
cat > /home/ubuntu/debug-runner.sh << 'DEBUGEOF'
#!/bin/bash
echo "=== GitHub Runner Debug Info ==="
echo "Date: \$(date)"
echo "Hostname: \$(hostname)"
echo "Public IP: \$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"
echo "Private IP: \$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)"
echo ""
echo "=== Service Status ==="
systemctl status actions.runner.* --no-pager
echo ""
echo "=== Runner Logs ==="
journalctl -u actions.runner.* --no-pager -n 50
echo ""
echo "=== Configuration Log ==="
cat /var/log/runner-config.log 2>/dev/null || echo "No config log found"
echo ""
echo "=== Cloud-init Log ==="
tail -50 /var/log/cloud-init-output.log
echo ""
echo "=== Runner Directory ==="
ls -la /home/ubuntu/actions-runner/
echo ""
echo "=== Network Test ==="
curl -s https://api.github.com/rate_limit | head -5
DEBUGEOF

chmod +x /home/ubuntu/debug-runner.sh
chown ubuntu:ubuntu /home/ubuntu/debug-runner.sh

echo "📋 Debug script created at /home/ubuntu/debug-runner.sh"
echo "📋 Configuration log at /var/log/runner-config.log"
echo "📋 Run 'sudo /home/ubuntu/debug-runner.sh' to troubleshoot"