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
REG_TOKEN=$(curl -X POST -H "Authorization: token ${github_token}" -H "Accept: application/vnd.github.v3+json" https://api.github.com/repos/${github_repo}/actions/runners/registration-token | grep -o '"token":"[^"]*' | cut -d'"' -f4)

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

sudo -u ubuntu ./config.sh --url https://github.com/${github_repo} --token $REG_TOKEN --name "$RUNNER_NAME" --labels "$LABELS" --unattended

# Install and start service
./svc.sh install ubuntu
./svc.sh start

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
K3S_IP=$(aws ec2 describe-instances --region $${AWS_REGION:-ap-south-1} \
  --filters "Name=tag:Name,Values=*k3s-node" "Name=instance-state-name,Values=running" \
  --query "Reservations[].Instances[0].PrivateIpAddress" --output text)

if [ "$K3S_IP" != "None" ] && [ -n "$K3S_IP" ]; then
  echo "Found K3s cluster at: $K3S_IP"
  # Direct access via private IP (same VPC)
  kubectl --server=https://$K3S_IP:6443 --insecure-skip-tls-verify get nodes
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

echo "🎉 GitHub runner configured successfully with custom software!"
echo "Runner name: $RUNNER_NAME"
echo "Labels: $LABELS"