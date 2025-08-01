#!/bin/bash
# One-liner to fix GitHub Actions runner service issue
cd /home/ubuntu/actions-runner && cat > svc.sh << 'EOF' && chmod +x svc.sh && ./svc.sh install ubuntu && ./svc.sh start
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
EOF