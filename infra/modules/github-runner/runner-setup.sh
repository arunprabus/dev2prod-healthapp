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

# Install SSM Agent
if ! systemctl is-active --quiet amazon-ssm-agent; then
    snap install amazon-ssm-agent --classic || apt install snapd -y && snap install amazon-ssm-agent --classic
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
chown -R ubuntu:ubuntu /home/ubuntu/actions-runner

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
./svc.sh install ubuntu >> /var/log/runner-config.log 2>&1
./svc.sh start >> /var/log/runner-config.log 2>&1
sleep 10

if ! systemctl is-active --quiet actions.runner.*; then
    sudo -u ubuntu bash -c "cd /home/ubuntu/actions-runner && nohup ./run.sh >> /var/log/runner-config.log 2>&1 &"
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

# Basic health monitor
cat > /home/ubuntu/monitor-runner.sh << 'EOF'
#!/bin/bash
if ! systemctl is-active --quiet actions.runner.*; then
    systemctl restart actions.runner.* || sudo -u ubuntu bash -c "cd /home/ubuntu/actions-runner && nohup ./run.sh &"
fi
EOF
chmod +x /home/ubuntu/monitor-runner.sh
echo "*/5 * * * * /home/ubuntu/monitor-runner.sh" | crontab -u ubuntu -

# Simple debug script
cat > /home/ubuntu/debug-runner.sh << 'EOF'
#!/bin/bash
systemctl status actions.runner.* --no-pager
ps aux | grep Runner
cat /var/log/runner-config.log
EOF
chmod +x /home/ubuntu/debug-runner.sh