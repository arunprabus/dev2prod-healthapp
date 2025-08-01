#!/bin/bash
set -e

echo "🔧 Fixing SSM Agent installation..."

# Check if snap version exists
if snap list amazon-ssm-agent 2>/dev/null; then
    echo "✅ SSM Agent installed via snap"
    sudo systemctl status snap.amazon-ssm-agent.amazon-ssm-agent.service
else
    echo "📦 Installing SSM Agent via snap..."
    sudo snap install amazon-ssm-agent --classic
    sudo systemctl enable snap.amazon-ssm-agent.amazon-ssm-agent.service
    sudo systemctl start snap.amazon-ssm-agent.amazon-ssm-agent.service
fi

# Check status
echo "📊 SSM Agent status:"
sudo systemctl status snap.amazon-ssm-agent.amazon-ssm-agent.service --no-pager

# Test registration
echo "🔍 Testing SSM registration..."
aws ssm describe-instance-information --filters "Key=InstanceIds,Values=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)" --query 'InstanceInformationList[0].PingStatus' --output text

echo "✅ SSM Agent fixed"