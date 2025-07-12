#!/bin/bash

# Diagnose GitHub Runner Issues
echo "=== GitHub Runner Diagnostics ==="

# Get runner instance IP
RUNNER_IP=$(aws ec2 describe-instances \
    --filters "Name=tag:Type,Values=github-runner" "Name=instance-state-name,Values=running" \
    --query "Reservations[0].Instances[0].PublicIpAddress" \
    --output text)

if [[ "$RUNNER_IP" == "None" || "$RUNNER_IP" == "" ]]; then
    echo "ERROR: No running GitHub runner found"
    exit 1
fi

echo "Runner IP: $RUNNER_IP"

# SSH and check logs
echo "=== Checking user-data logs ==="
ssh -i ~/.ssh/k3s-key -o StrictHostKeyChecking=no ubuntu@$RUNNER_IP "sudo tail -50 /var/log/user-data.log"

echo ""
echo "=== Checking runner service status ==="
ssh -i ~/.ssh/k3s-key -o StrictHostKeyChecking=no ubuntu@$RUNNER_IP "sudo systemctl status actions.runner.*.service"

echo ""
echo "=== Checking runner logs ==="
ssh -i ~/.ssh/k3s-key -o StrictHostKeyChecking=no ubuntu@$RUNNER_IP "sudo journalctl -u actions.runner.*.service --no-pager -n 20"

echo ""
echo "=== Testing GitHub connectivity ==="
ssh -i ~/.ssh/k3s-key -o StrictHostKeyChecking=no ubuntu@$RUNNER_IP "curl -s --connect-timeout 5 https://api.github.com/zen"

echo ""
echo "=== Checking runner directory ==="
ssh -i ~/.ssh/k3s-key -o StrictHostKeyChecking=no ubuntu@$RUNNER_IP "ls -la /home/ubuntu/actions-runner/"