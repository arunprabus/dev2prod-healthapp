#!/bin/bash
set -e

echo "🚀 Quick GitHub Runner Service Fix"

# Navigate to runner directory
cd /home/ubuntu/actions-runner

# Create svc.sh if missing
if [ ! -f "svc.sh" ]; then
    echo "Creating svc.sh..."
    cat > svc.sh << 'EOF'
#!/bin/bash
SVC_NAME="actions.runner.$(cat .runner | jq -r '.gitHubUrl' | sed 's/https:\/\/github.com\///').$(cat .runner | jq -r '.runnerName').service"
SVC_DESCRIPTION="GitHub Actions Runner ($(cat .runner | jq -r '.gitHubUrl' | sed 's/https:\/\/github.com\///').$(cat .runner | jq -r '.runnerName'))"
USER_ID=${2:-ubuntu}
RUNNER_ROOT=$(pwd)

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
        echo "Service installed"
        ;;
    start)
        sudo systemctl start $SVC_NAME
        echo "Service started"
        ;;
    stop)
        sudo systemctl stop $SVC_NAME
        echo "Service stopped"
        ;;
    status)
        sudo systemctl status $SVC_NAME
        ;;
    uninstall)
        sudo systemctl stop $SVC_NAME || true
        sudo systemctl disable $SVC_NAME || true
        sudo rm -f /etc/systemd/system/$SVC_NAME
        sudo systemctl daemon-reload
        echo "Service uninstalled"
        ;;
    *)
        echo "Usage: $0 {install|start|stop|status|uninstall} [user]"
        exit 1
        ;;
esac
EOF
    chmod +x svc.sh
    echo "✅ svc.sh created"
fi

# Install and start service
echo "Installing service..."
./svc.sh install ubuntu

echo "Starting service..."
./svc.sh start

echo "Checking status..."
./svc.sh status

echo "✅ Runner service is now running!"