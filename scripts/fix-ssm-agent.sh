#!/bin/bash

# Fix SSM Agent on K3s instance
# Usage: ./fix-ssm-agent.sh <environment>

ENVIRONMENT=${1:-dev}
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}🔧 Fixing SSM Agent on K3s instance${NC}"

# Map environment to network tier
case $ENVIRONMENT in
    "dev"|"test") NETWORK_TIER="lower" ;;
    "prod") NETWORK_TIER="higher" ;;
    "monitoring") NETWORK_TIER="monitoring" ;;
    *) echo -e "${RED}❌ Invalid environment${NC}"; exit 1 ;;
esac

# Get K3s instance IP
K3S_IP=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=health-app-${NETWORK_TIER}-k3s-node" \
              "Name=instance-state-name,Values=running" \
    --query 'Reservations[0].Instances[0].PublicIpAddress' \
    --output text 2>/dev/null)

if [ "$K3S_IP" = "None" ] || [ -z "$K3S_IP" ]; then
    echo -e "${RED}❌ K3s instance not found${NC}"
    exit 1
fi

echo -e "${YELLOW}K3s IP: ${K3S_IP}${NC}"

# Create SSM installation script
cat > /tmp/install-ssm.sh << 'EOF'
#!/bin/bash
set -e

echo "🔧 Installing SSM Agent..."

# Method 1: Debian package
cd /tmp
wget -q https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/debian_amd64/amazon-ssm-agent.deb
if dpkg -i amazon-ssm-agent.deb 2>/dev/null; then
    echo "✅ Installed via .deb package"
    systemctl enable amazon-ssm-agent
    systemctl start amazon-ssm-agent
else
    echo "⚠️ .deb failed, trying snap..."
    # Method 2: Snap package
    snap install amazon-ssm-agent --classic
    systemctl enable snap.amazon-ssm-agent.amazon-ssm-agent.service
    systemctl start snap.amazon-ssm-agent.amazon-ssm-agent.service
fi

# Check status
sleep 5
if systemctl is-active amazon-ssm-agent >/dev/null 2>&1; then
    echo "✅ SSM Agent is running (systemd)"
elif systemctl is-active snap.amazon-ssm-agent.amazon-ssm-agent >/dev/null 2>&1; then
    echo "✅ SSM Agent is running (snap)"
else
    echo "❌ SSM Agent not running"
    exit 1
fi

echo "🎉 SSM Agent installation complete!"
EOF

# Upload and execute
echo -e "${YELLOW}📤 Uploading installation script...${NC}"
scp -i ~/.ssh/k3s-key -o StrictHostKeyChecking=no /tmp/install-ssm.sh ubuntu@$K3S_IP:/tmp/

echo -e "${YELLOW}🚀 Executing installation...${NC}"
ssh -i ~/.ssh/k3s-key -o StrictHostKeyChecking=no ubuntu@$K3S_IP "sudo bash /tmp/install-ssm.sh"

echo -e "${GREEN}✅ SSM Agent fix completed!${NC}"
echo -e "${YELLOW}💡 Wait 2-3 minutes, then check AWS Console → Systems Manager → Fleet Manager${NC}"