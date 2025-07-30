#!/bin/bash
set -e

# Variables
METADATA_IP="${metadata_ip}"
S3_BUCKET="${s3_bucket}"

echo "🚀 Setting up GitHub Runner..."

# Update system (cached)
if [ ! -f "/var/cache/apt/pkgcache.bin" ] || [ $(find /var/cache/apt/pkgcache.bin -mtime +1) ]; then
  apt-get update
fi
apt-get install -y curl wget unzip docker.io git jq

# Install Terraform (cached)
echo "📦 Installing Terraform..."
if ! command -v terraform >/dev/null; then
  wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | tee /usr/share/keyrings/hashicorp-archive-keyring.gpg
  echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list
  apt-get update && apt-get install -y terraform
else
  echo "✅ Terraform already installed"
fi

# Install kubectl (cached)
echo "☸️ Installing kubectl..."
if ! command -v kubectl >/dev/null; then
  curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
  chmod +x kubectl
  mv kubectl /usr/local/bin/
else
  echo "✅ kubectl already installed"
fi

# Install AWS CLI v2 (cached)
echo "☁️ Installing AWS CLI..."
if ! command -v aws >/dev/null; then
  curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
  unzip awscliv2.zip
  ./aws/install
  rm -rf aws awscliv2.zip
else
  echo "✅ AWS CLI already installed"
fi

# Install SSM Agent (single installation with proper error handling)
echo "🔧 Installing SSM Agent..."
if ! systemctl is-active --quiet amazon-ssm-agent; then
    if wget -q https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/debian_amd64/amazon-ssm-agent.deb; then
        dpkg -i amazon-ssm-agent.deb || apt-get install -f -y
        systemctl enable amazon-ssm-agent
        systemctl start amazon-ssm-agent
        echo "✅ SSM Agent installed via deb package"
    else
        echo "Deb installation failed, trying snap..."
        if ! command -v snap >/dev/null; then
            apt install snapd -y
        fi
        if snap install amazon-ssm-agent --classic; then
            echo "✅ SSM Agent installed via snap"
        else
            echo "⚠️ SSM Agent installation failed, but continuing..."
        fi
    fi
else
    echo "✅ SSM Agent already running"
fi

# Install Docker Compose (cached)
echo "🐳 Installing Docker Compose..."
if ! command -v docker-compose >/dev/null; then
  curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
  chmod +x /usr/local/bin/docker-compose
else
  echo "✅ Docker Compose already installed"
fi

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
mkdir -p actions-runner && cd actions-runner

# Download latest runner (cached)
if [ ! -f "actions-runner-linux-x64-2.311.0.tar.gz" ]; then
  curl -o actions-runner-linux-x64-2.311.0.tar.gz -L https://github.com/actions/runner/releases/download/v2.311.0/actions-runner-linux-x64-2.311.0.tar.gz
else
  echo "✅ Runner package already downloaded"
fi
tar xzf ./actions-runner-linux-x64-2.311.0.tar.gz

# Fix ownership
chown -R ubuntu:ubuntu /home/ubuntu/actions-runner

# Get registration token using PAT
echo "🔐 Registering runner with GitHub..."
echo "Repository: ${github_repo}"

# Clean up existing runners for this network tier
echo "🧹 Cleaning up existing runners for network: ${network_tier}..."
EXISTING_RUNNERS=$(curl -s -H "Authorization: token ${github_token}" -H "Accept: application/vnd.github.v3+json" https://api.github.com/repos/${github_repo}/actions/runners | jq -r ".runners[] | select(.name | contains(\"github-runner-${network_tier}\")) | .id")

echo "Found existing runners for ${network_tier}: $EXISTING_RUNNERS"
for runner_id in $EXISTING_RUNNERS; do
    if [ ! -z "$runner_id" ] && [ "$runner_id" != "null" ]; then
        echo "🗑️ Removing runner ID: $runner_id"
        curl -s -X DELETE -H "Authorization: token ${github_token}" -H "Accept: application/vnd.github.v3+json" https://api.github.com/repos/${github_repo}/actions/runners/$runner_id
        sleep 2
    fi
done

echo "⏳ Waiting for cleanup to complete..."
sleep 10

# Get registration token
echo "Getting registration token..."
REG_TOKEN=$(curl -s -X POST -H "Authorization: token ${github_token}" -H "Accept: application/vnd.github.v3+json" https://api.github.com/repos/${github_repo}/actions/runners/registration-token | jq -r '.token')
echo "Token obtained: $${REG_TOKEN:0:10}..."

# Create service with clean naming
RUNNER_NAME="github-runner-${network_tier}-$(hostname | cut -d'-' -f3-)"
LABELS="github-runner-${network_tier}"

echo "🚀 Configuring NEW runner: $RUNNER_NAME"
echo "🏷️ Labels: $LABELS"
echo "🌐 Network tier: ${network_tier}"

# Configure runner as ubuntu user
echo "Running configuration as ubuntu user..."
sudo -u ubuntu bash -c "cd /home/ubuntu/actions-runner && ./config.sh --url https://github.com/${github_repo} --token $REG_TOKEN --name '$RUNNER_NAME' --labels '$LABELS' --unattended --replace" > /var/log/runner-config.log 2>&1
CONFIG_EXIT_CODE=$?
echo "Runner configuration exit code: $CONFIG_EXIT_CODE"

# Install and start service
echo "Installing runner service..."
cd /home/ubuntu/actions-runner
./svc.sh install ubuntu
./svc.sh start
sleep 10

# Check service status
if systemctl is-active --quiet actions.runner.*; then
    echo "✅ Runner service started successfully"
else
    echo "⚠️ Service failed, trying direct start..."
    sudo -u ubuntu bash -c "cd /home/ubuntu/actions-runner && nohup ./run.sh > /dev/null 2>&1 &"
fi

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
echo "Public IP: $(curl -s http://$METADATA_IP/latest/meta-data/public-ipv4)"

# Setup EBS volume for logs
echo "💾 Setting up EBS volume for logs..."
while [ ! -e /dev/xvdf ]; do
  echo "Waiting for EBS volume to attach..."
  sleep 5
done

# Format and mount EBS volume
if ! blkid /dev/xvdf; then
  echo "Formatting EBS volume..."
  mkfs.ext4 /dev/xvdf
fi

mkdir -p /var/log/runner-logs
mount /dev/xvdf /var/log/runner-logs
echo "/dev/xvdf /var/log/runner-logs ext4 defaults 0 2" >> /etc/fstab
chown ubuntu:ubuntu /var/log/runner-logs

# Setup log shipping to S3
echo "📤 Setting up log shipping to S3..."
cat > /home/ubuntu/ship-logs-to-s3.sh << LOGEOF
#!/bin/bash
LOG_DATE=\$(date +%Y-%m-%d)
S3_BUCKET="$S3_BUCKET"
NETWORK_TIER="${network_tier}"
INSTANCE_ID=\$(curl -s http://$METADATA_IP/latest/meta-data/instance-id)

# Create daily log archive
tar -czf /tmp/runner-logs-\$LOG_DATE.tar.gz -C /var/log/runner-logs . 2>/dev/null || true
tar -czf /tmp/system-logs-\$LOG_DATE.tar.gz /var/log/runner-config.log /var/log/cloud-init-output.log 2>/dev/null || true

# Upload to S3
aws s3 cp /tmp/runner-logs-\$LOG_DATE.tar.gz s3://\$S3_BUCKET/runner-logs/\$NETWORK_TIER/\$INSTANCE_ID/runner-logs-\$LOG_DATE.tar.gz 2>/dev/null || true
aws s3 cp /tmp/system-logs-\$LOG_DATE.tar.gz s3://\$S3_BUCKET/runner-logs/\$NETWORK_TIER/\$INSTANCE_ID/system-logs-\$LOG_DATE.tar.gz 2>/dev/null || true

# Cleanup old local files (keep last 3 days)
find /var/log/runner-logs -name "*.log" -mtime +3 -delete 2>/dev/null || true
rm -f /tmp/*logs-*.tar.gz

echo "\$(date): Logs shipped to S3" >> /var/log/runner-logs/ship.log
LOGEOF

chmod +x /home/ubuntu/ship-logs-to-s3.sh
chown ubuntu:ubuntu /home/ubuntu/ship-logs-to-s3.sh

# Create runner health monitor
echo "🔍 Setting up runner health monitor..."
cat > /home/ubuntu/monitor-runner.sh << MONEOF
#!/bin/bash
LOG_FILE="/var/log/runner-logs/health-monitor.log"
echo "\$(date): Checking runner health..." >> \$LOG_FILE

# Check if service is running
if systemctl is-active --quiet actions.runner.*; then
    echo "\$(date): ✅ Service is active" >> \$LOG_FILE
else
    echo "\$(date): ❌ Service is not active, restarting..." >> \$LOG_FILE
    systemctl restart actions.runner.* >> \$LOG_FILE 2>&1
    sleep 10
fi

# Check if Runner.Listener process exists
if pgrep -f Runner.Listener > /dev/null; then
    echo "\$(date): ✅ Runner.Listener process is running" >> \$LOG_FILE
else
    echo "\$(date): ⚠️ Runner.Listener process not found" >> \$LOG_FILE
    systemctl restart actions.runner.* >> \$LOG_FILE 2>&1
    sleep 10
    
    if ! pgrep -f Runner.Listener > /dev/null; then
        echo "\$(date): 🔄 Attempting direct start..." >> \$LOG_FILE
        pkill -f Runner.Listener || true
        sleep 5
        sudo -u ubuntu bash -c "cd /home/ubuntu/actions-runner && nohup ./run.sh >> \$LOG_FILE 2>&1 &"
    fi
fi

# Check GitHub connectivity
if curl -s --connect-timeout 10 https://api.github.com/rate_limit > /dev/null; then
    echo "\$(date): ✅ GitHub API connectivity OK" >> \$LOG_FILE
else
    echo "\$(date): ❌ GitHub API connectivity failed" >> \$LOG_FILE
fi

# Keep only last 100 lines of log
tail -100 \$LOG_FILE > /tmp/health-monitor.tmp && mv /tmp/health-monitor.tmp \$LOG_FILE
MONEOF

chmod +x /home/ubuntu/monitor-runner.sh
chown ubuntu:ubuntu /home/ubuntu/monitor-runner.sh

# Setup cron jobs
(
  echo "0 2 * * * /home/ubuntu/ship-logs-to-s3.sh"
  echo "*/5 * * * * /home/ubuntu/monitor-runner.sh"
) | crontab -u ubuntu -

# Create debug and restart scripts
cat > /home/ubuntu/debug-runner.sh << 'DEBUGEOF'
#!/bin/bash
echo "=== Runner Status ==="
systemctl status actions.runner.* --no-pager
echo "=== Runner Logs ==="
journalctl -u actions.runner.* --no-pager -n 20
echo "=== Config Log ==="
cat /var/log/runner-config.log
echo "=== EBS Volume Status ==="
df -h /var/log/runner-logs
echo "=== Recent Log Files ==="
ls -la /var/log/runner-logs/ | head -10
echo "=== S3 Log Shipping Status ==="
tail -5 /var/log/runner-logs/ship.log 2>/dev/null || echo "No shipping log yet"
DEBUGEOF

cat > /home/ubuntu/restart-runner.sh << 'RESTEOF'
#!/bin/bash
echo "🔄 Restarting GitHub Actions Runner..."
echo "$(date): Manual restart initiated" >> /var/log/runner-logs/health-monitor.log

sudo systemctl stop actions.runner.*
sleep 5
sudo pkill -f Runner.Listener || true
sudo pkill -f RunnerService.js || true
sleep 5
sudo systemctl start actions.runner.*
sleep 10

if systemctl is-active --quiet actions.runner.*; then
    echo "✅ Runner restarted successfully"
    sudo systemctl status actions.runner.* --no-pager
else
    echo "❌ Service restart failed, trying direct start..."
    cd /home/ubuntu/actions-runner
    nohup ./run.sh > /var/log/runner-logs/direct-run.log 2>&1 &
    sleep 5
    if pgrep -f Runner.Listener > /dev/null; then
        echo "✅ Runner started via direct method"
    else
        echo "❌ All restart methods failed"
    fi
fi
RESTEOF

chmod +x /home/ubuntu/debug-runner.sh /home/ubuntu/restart-runner.sh
chown ubuntu:ubuntu /home/ubuntu/debug-runner.sh /home/ubuntu/restart-runner.sh

echo "📋 Debug script: /home/ubuntu/debug-runner.sh"
echo "📋 Config log: /var/log/runner-config.log"
echo "💾 Runner logs: /var/log/runner-logs/"
echo "📤 Log shipping: /home/ubuntu/ship-logs-to-s3.sh (runs daily at 2 AM)"
echo "🔍 Health monitor: /home/ubuntu/monitor-runner.sh (runs every 5 minutes)"
echo "🔄 Restart script: /home/ubuntu/restart-runner.sh"