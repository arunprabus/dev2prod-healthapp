#!/bin/bash
set -e

INSTANCE_ID="$1"
GITHUB_TOKEN="$2"
GITHUB_REPO="$3"
NETWORK_TIER="$4"
REGION="${5:-ap-south-1}"

echo "🔐 Setting up GitHub runner via KMS-encrypted Run Command..."

# Create KMS-encrypted runner setup script
RUNNER_SCRIPT=$(cat << 'EOF'
#!/bin/bash
set -e
cd /home/ubuntu/actions-runner || exit 1

# Create svc.sh if missing
if [ ! -f "svc.sh" ]; then
cat > svc.sh << 'SVCEOF'
#!/bin/bash
SVC_NAME="actions.runner.$(cat .runner | jq -r '.gitHubUrl' | sed 's/https:\/\/github.com\///').$(cat .runner | jq -r '.runnerName').service"
USER_ID=${2:-ubuntu}
RUNNER_ROOT=$(pwd)
case $1 in
    install)
        sudo tee /etc/systemd/system/$SVC_NAME > /dev/null << UNIT
[Unit]
Description=GitHub Actions Runner
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
esac
SVCEOF
chmod +x svc.sh
fi

# Install and start service
./svc.sh install ubuntu
./svc.sh start
systemctl status actions.runner.*.service --no-pager
EOF
)

# Execute via Run Command
COMMAND_ID=$(aws ssm send-command \
    --instance-ids "$INSTANCE_ID" \
    --document-name "AWS-RunShellScript" \
    --parameters "commands=[\"$RUNNER_SCRIPT\"]" \
    --region "$REGION" \
    --query 'Command.CommandId' \
    --output text)

echo "⏳ Waiting for runner setup completion..."
aws ssm wait command-executed \
    --command-id "$COMMAND_ID" \
    --instance-id "$INSTANCE_ID" \
    --region "$REGION"

# Get results
aws ssm get-command-invocation \
    --command-id "$COMMAND_ID" \
    --instance-id "$INSTANCE_ID" \
    --region "$REGION" \
    --query 'StandardOutputContent' \
    --output text

echo "✅ Runner service setup completed via Run Command"