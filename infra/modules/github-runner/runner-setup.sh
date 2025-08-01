#!/bin/bash
set -e

apt-get update
apt-get install -y curl wget unzip docker.io git jq

# Install tools
if ! command -v terraform >/dev/null; then
  wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | tee /usr/share/keyrings/hashicorp-archive-keyring.gpg
  echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list
  apt-get update && apt-get install -y terraform
fi

if ! command -v kubectl >/dev/null; then
  curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
  chmod +x kubectl && mv kubectl /usr/local/bin/
fi

if ! command -v aws >/dev/null; then
  curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
  unzip awscliv2.zip && ./aws/install && rm -rf aws awscliv2.zip
fi

# Install SSM Agent properly
if ! systemctl is-active --quiet amazon-ssm-agent; then
    # Try snap first
    if command -v snap >/dev/null; then
        snap install amazon-ssm-agent --classic
    else
        # Install snapd and then SSM agent
        apt install snapd -y
        snap install amazon-ssm-agent --classic
    fi
    # Enable and start SSM agent
    systemctl enable snap.amazon-ssm-agent.amazon-ssm-agent.service
    systemctl start snap.amazon-ssm-agent.amazon-ssm-agent.service
fi

# Install additional tools
if ! command -v docker-compose >/dev/null; then
  curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
  chmod +x /usr/local/bin/docker-compose
fi

curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt-get install -y nodejs python3 python3-pip

# Install GitHub Actions runner
cd /home/ubuntu
mkdir -p actions-runner && cd actions-runner
curl -o actions-runner-linux-x64-2.311.0.tar.gz -L https://github.com/actions/runner/releases/download/v2.311.0/actions-runner-linux-x64-2.311.0.tar.gz
tar xzf ./actions-runner-linux-x64-2.311.0.tar.gz

# Create symlink for root access
ln -sf /home/ubuntu/actions-runner /root/actions-runner

# Fix ownership
chown -R ubuntu:ubuntu /home/ubuntu/actions-runner
chmod +x /home/ubuntu/actions-runner/*.sh

# Clean up existing runners
EXISTING_RUNNERS=$(curl -s -H "Authorization: token ${github_token}" -H "Accept: application/vnd.github.v3+json" https://api.github.com/repos/${github_repo}/actions/runners | jq -r ".runners[] | select(.name | contains(\"github-runner-${network_tier}\")) | .id")
for runner_id in $EXISTING_RUNNERS; do
    if [ ! -z "$runner_id" ] && [ "$runner_id" != "null" ]; then
        curl -s -X DELETE -H "Authorization: token ${github_token}" -H "Accept: application/vnd.github.v3+json" https://api.github.com/repos/${github_repo}/actions/runners/$runner_id
    fi
done
sleep 10

# Get registration token
REG_TOKEN=$(curl -s -X POST -H "Authorization: token ${github_token}" -H "Accept: application/vnd.github.v3+json" https://api.github.com/repos/${github_repo}/actions/runners/registration-token | jq -r '.token')
RUNNER_NAME="github-runner-${network_tier}-$(hostname | cut -d'-' -f3-)"
LABELS="github-runner-${network_tier}"

# Configure runner
echo "$(date): Starting runner configuration" > /var/log/runner-config.log
sudo -u ubuntu bash -c "cd /home/ubuntu/actions-runner && ./config.sh --url https://github.com/${github_repo} --token $REG_TOKEN --name '$RUNNER_NAME' --labels '$LABELS' --unattended --replace" >> /var/log/runner-config.log 2>&1

# Install and start service
cd /home/ubuntu/actions-runner

# Install service as root (required for systemd service creation)
./svc.sh install ubuntu

# Enable and start the service
systemctl enable actions.runner.*
systemctl start actions.runner.*

# Wait and verify service is running
sleep 15

# Check if service is running
if systemctl is-active --quiet actions.runner.*; then
    echo "Runner service started successfully" >> /var/log/runner-config.log
    systemctl status actions.runner.* --no-pager >> /var/log/runner-config.log 2>&1
else
    echo "Service failed, trying direct start" >> /var/log/runner-config.log
    systemctl status actions.runner.* --no-pager >> /var/log/runner-config.log 2>&1
    # Fallback to direct start
    sudo -u ubuntu bash -c "cd /home/ubuntu/actions-runner && nohup ./run.sh >> /var/log/runner-config.log 2>&1 &"
    sleep 5
fi

# Final verification
if pgrep -f "Runner.Listener" > /dev/null || systemctl is-active --quiet actions.runner.*; then
    echo "Runner is running" >> /var/log/runner-config.log
else
    echo "Runner failed to start" >> /var/log/runner-config.log
fi

usermod -aG docker ubuntu
echo "$(date): Setup completed" >> /var/log/runner-config.log

# Setup EBS volume
while [ ! -e /dev/xvdf ]; do sleep 5; done
if ! blkid /dev/xvdf; then mkfs.ext4 /dev/xvdf; fi
mkdir -p /var/log/runner-logs
mount /dev/xvdf /var/log/runner-logs
echo "/dev/xvdf /var/log/runner-logs ext4 defaults 0 2" >> /etc/fstab
chown ubuntu:ubuntu /var/log/runner-logs

# Health monitor with proper service management
cat > /home/ubuntu/monitor-runner.sh << 'EOF'
#!/bin/bash
LOG_FILE="/var/log/runner-logs/health-monitor.log"
echo "$(date): Checking runner health" >> $LOG_FILE

if ! systemctl is-active --quiet actions.runner.*; then
    echo "$(date): Service inactive, restarting" >> $LOG_FILE
    systemctl restart actions.runner.* >> $LOG_FILE 2>&1
    sleep 10
    
    if ! systemctl is-active --quiet actions.runner.*; then
        echo "$(date): Service restart failed, trying direct start" >> $LOG_FILE
        sudo -u ubuntu bash -c "cd /home/ubuntu/actions-runner && nohup ./run.sh >> $LOG_FILE 2>&1 &"
    fi
fi
EOF

chmod +x /home/ubuntu/monitor-runner.sh
chown ubuntu:ubuntu /home/ubuntu/monitor-runner.sh

# Add to root crontab since it needs systemctl access
echo "*/5 * * * * /home/ubuntu/monitor-runner.sh" | crontab -

# Create startup script for boot
cat > /etc/systemd/system/github-runner-startup.service << 'EOF'
[Unit]
Description=GitHub Runner Startup
After=network.target

[Service]
Type=oneshot
ExecStart=/home/ubuntu/start-runner-on-boot.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

cat > /home/ubuntu/start-runner-on-boot.sh << 'EOF'
#!/bin/bash
sleep 30
if ! systemctl is-active --quiet actions.runner.*; then
    systemctl start actions.runner.* || {
        cd /home/ubuntu/actions-runner
        sudo -u ubuntu nohup ./run.sh > /var/log/runner-config.log 2>&1 &
    }
fi
EOF

chmod +x /home/ubuntu/start-runner-on-boot.sh
systemctl enable github-runner-startup.service

# Debug and restart scripts
cat > /home/ubuntu/debug-runner.sh << 'EOF'
#!/bin/bash
echo "=== Service Status ==="
systemctl status actions.runner.* --no-pager 2>/dev/null || echo "No service found"
echo "=== Process Status ==="
ps aux | grep Runner | grep -v grep || echo "No runner process"
echo "=== Actions Runner Directory ==="
ls -la /home/ubuntu/actions-runner/ 2>/dev/null || echo "Directory not found"
echo "=== Config Log ==="
tail -20 /var/log/runner-config.log 2>/dev/null || echo "No config log"
echo "=== Service Files ==="
ls -la /etc/systemd/system/actions.runner.* 2>/dev/null || echo "No service files"
EOF

cat > /home/ubuntu/restart-runner.sh << 'EOF'
#!/bin/bash
echo "Stopping runner service..."
systemctl stop actions.runner.*
sleep 5
pkill -f Runner.Listener || true
sleep 5
echo "Starting runner service..."
systemctl start actions.runner.*
sleep 10
if systemctl is-active --quiet actions.runner.*; then
    echo "Service restarted successfully"
    systemctl status actions.runner.* --no-pager
else
    echo "Service failed, trying direct start"
    cd /home/ubuntu/actions-runner
    sudo -u ubuntu nohup ./run.sh > /var/log/runner-logs/direct-run.log 2>&1 &
fi
EOF

chmod +x /home/ubuntu/debug-runner.sh /home/ubuntu/restart-runner.sh
chown ubuntu:ubuntu /home/ubuntu/debug-runner.sh /home/ubuntu/restart-runner.sh