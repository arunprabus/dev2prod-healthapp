#!/bin/bash
set -e
exec > >(tee /var/log/runner-setup.log) 2>&1

echo "🚀 Setting up GitHub Runner..."
echo "Time: $(date)"

# Update system
echo "Updating system..."
apt-get update
apt-get install -y curl wget unzip git jq docker.io

# Setup GitHub Actions runner
echo "Setting up runner directory..."
cd /home/ubuntu
mkdir -p actions-runner && cd actions-runner

echo "Downloading runner..."
curl -o actions-runner-linux-x64-2.311.0.tar.gz -L https://github.com/actions/runner/releases/download/v2.311.0/actions-runner-linux-x64-2.311.0.tar.gz
tar xzf ./actions-runner-linux-x64-2.311.0.tar.gz
chown -R ubuntu:ubuntu /home/ubuntu/actions-runner

echo "Getting registration token..."
REG_TOKEN=$(curl -s -X POST -H "Authorization: token ${github_token}" -H "Accept: application/vnd.github.v3+json" https://api.github.com/repos/${github_repo}/actions/runners/registration-token | jq -r '.token')
RUNNER_NAME="github-runner-${network_tier}-$(hostname | cut -d'-' -f3-)"
LABELS="github-runner-${network_tier}"

echo "Configuring runner: $RUNNER_NAME"
sudo -u ubuntu bash -c "cd /home/ubuntu/actions-runner && ./config.sh --url https://github.com/${github_repo} --token $REG_TOKEN --name '$RUNNER_NAME' --labels '$LABELS' --unattended"

echo "Installing service..."
./svc.sh install ubuntu

echo "Starting service..."
./svc.sh start

# Add ubuntu to docker group
usermod -aG docker ubuntu

echo "✅ Setup completed at $(date)"
echo "Runner: $RUNNER_NAME"
echo "Labels: $LABELS"

# Create debug script
cat > /home/ubuntu/debug-runner.sh << 'EOF'
#!/bin/bash
echo "=== Runner Status ==="
sudo systemctl status actions.runner.* --no-pager
echo "=== Setup Log ==="
tail -50 /var/log/runner-setup.log
echo "=== Directory ==="
ls -la /home/ubuntu/actions-runner/
EOF
chmod +x /home/ubuntu/debug-runner.sh
chown ubuntu:ubuntu /home/ubuntu/debug-runner.sh