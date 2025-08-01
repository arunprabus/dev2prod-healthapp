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

# Fix missing svc.sh if needed
if [ ! -f "svc.sh" ]; then
    echo "🔧 Creating missing svc.sh script..."
    cat > svc.sh << 'SVCEOF'
#!/bin/bash
SVC_NAME="actions.runner.$(cat .runner | jq -r '.gitHubUrl' | sed 's/https:\/\/github.com\///').$(cat .runner | jq -r '.runnerName').service"
SVC_DESCRIPTION="GitHub Actions Runner ($(cat .runner | jq -r '.gitHubUrl' | sed 's/https:\/\/github.com\///').$(cat .runner | jq -r '.runnerName'))"
USER_ID=$2
RUNNER_ROOT=$(pwd)
if [ -z "$USER_ID" ]; then USER_ID=$(whoami); fi
case $1 in
    install)
        sudo tee /etc/systemd/system/$SVC_NAME > /dev/null << UNIT
[Unit]
Description=$SVC_DESCRIPTION
After=network.target
[Service]
ExecStart=$RUNNER_ROOT/run.sh
User=$USER_ID
WorkingDirectory=$RUNNER_ROOT
KillMode=process
KillSignal=SIGTERM
TimeoutStopSec=5min
[Install]
WantedBy=multi-user.target
UNIT
        sudo systemctl daemon-reload
        sudo systemctl enable $SVC_NAME
        ;;
    start) sudo systemctl start $SVC_NAME ;;
    stop) sudo systemctl stop $SVC_NAME ;;
    status) sudo systemctl status $SVC_NAME ;;
    uninstall)
        sudo systemctl stop $SVC_NAME || true
        sudo systemctl disable $SVC_NAME || true
        sudo rm -f /etc/systemd/system/$SVC_NAME
        sudo systemctl daemon-reload
        ;;
    *) echo "Usage: $0 {install|start|stop|status|uninstall} [user]"; exit 1 ;;
esac
SVCEOF
    chmod +x svc.sh
fi

# Install and start service
./svc.sh install ubuntu
./svc.sh start

usermod -aG docker ubuntu
echo "✅ Runner setup completed!"