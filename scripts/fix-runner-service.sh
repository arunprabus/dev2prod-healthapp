#!/bin/bash
set -e

echo "🔧 Fixing GitHub Actions Runner Service Setup..."

# Navigate to runner directory
cd /home/ubuntu/actions-runner

# Check if svc.sh exists
if [ ! -f "svc.sh" ]; then
    echo "❌ svc.sh not found, creating it..."
    
    # Create the svc.sh script manually
    cat > svc.sh << 'EOF'
#!/bin/bash

# GitHub Actions Runner Service Management Script

SVC_NAME="actions.runner.$(cat .runner | jq -r '.gitHubUrl' | sed 's/https:\/\/github.com\///').$(cat .runner | jq -r '.runnerName').service"
SVC_DESCRIPTION="GitHub Actions Runner ($(cat .runner | jq -r '.gitHubUrl' | sed 's/https:\/\/github.com\///').$(cat .runner | jq -r '.runnerName'))"

USER_ID=$2
RUNNER_ROOT=$(pwd)

if [ -z "$USER_ID" ]; then
    USER_ID=$(whoami)
fi

case $1 in
    install)
        echo "Creating systemd service..."
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
        echo "Service installed successfully"
        ;;
    start)
        echo "Starting service..."
        sudo systemctl start $SVC_NAME
        echo "Service started"
        ;;
    stop)
        echo "Stopping service..."
        sudo systemctl stop $SVC_NAME
        echo "Service stopped"
        ;;
    status)
        sudo systemctl status $SVC_NAME
        ;;
    uninstall)
        echo "Uninstalling service..."
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
    echo "✅ svc.sh created successfully"
else
    echo "✅ svc.sh already exists"
fi

# Install and start the service
echo "🚀 Installing and starting runner service..."
./svc.sh install ubuntu
./svc.sh start

# Check service status
echo "📊 Service status:"
./svc.sh status

echo "✅ Runner service setup completed!"