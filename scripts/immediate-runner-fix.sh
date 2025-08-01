#!/bin/bash
# Immediate fix for current runner issue using AWS Run Command

INSTANCE_ID="i-0123456789abcdef0"  # Replace with your instance ID
REGION="ap-south-1"

RUNNER_FIX='#!/bin/bash
cd /home/ubuntu/actions-runner
cat > svc.sh << "EOF"
#!/bin/bash
SVC_NAME="actions.runner.$(cat .runner | jq -r ".gitHubUrl" | sed "s/https:\/\/github.com\///").$(cat .runner | jq -r ".runnerName").service"
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
EOF
chmod +x svc.sh
./svc.sh install ubuntu
./svc.sh start
./svc.sh status'

echo "🚀 Fixing runner via AWS Run Command..."

COMMAND_ID=$(aws ssm send-command \
    --instance-ids "$INSTANCE_ID" \
    --document-name "AWS-RunShellScript" \
    --parameters "commands=[\"$RUNNER_FIX\"]" \
    --region "$REGION" \
    --query 'Command.CommandId' \
    --output text)

echo "Command ID: $COMMAND_ID"
echo "⏳ Waiting for completion..."

aws ssm wait command-executed \
    --command-id "$COMMAND_ID" \
    --instance-id "$INSTANCE_ID" \
    --region "$REGION"

echo "📋 Output:"
aws ssm get-command-invocation \
    --command-id "$COMMAND_ID" \
    --instance-id "$INSTANCE_ID" \
    --region "$REGION" \
    --query 'StandardOutputContent' \
    --output text

echo "✅ Runner service fixed!"