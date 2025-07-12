#!/bin/bash

# Install SSM Agent on existing instances
# Usage: ./install-ssm-agent.sh <environment>

ENVIRONMENT=${1:-lower}
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}🔧 Installing SSM Agent${NC}"
echo -e "${YELLOW}Environment: ${ENVIRONMENT}${NC}"

# Map environment to network tier
case $ENVIRONMENT in
    "dev"|"test") NETWORK_TIER="lower" ;;
    "prod") NETWORK_TIER="higher" ;;
    "monitoring") NETWORK_TIER="monitoring" ;;
    *) echo -e "${RED}❌ Invalid environment${NC}"; exit 1 ;;
esac

# Get K3s instance
K3S_INSTANCE=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=health-app-${NETWORK_TIER}-k3s-node-v2" \
              "Name=instance-state-name,Values=running" \
    --query 'Reservations[0].Instances[0].[InstanceId,PublicIpAddress]' \
    --output text 2>/dev/null)

# Get GitHub runner instance
RUNNER_INSTANCE=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=health-app-runner-${NETWORK_TIER}" \
              "Name=instance-state-name,Values=running" \
    --query 'Reservations[0].Instances[0].[InstanceId,PublicIpAddress]' \
    --output text 2>/dev/null)

install_ssm_on_instance() {
    local instance_id=$1
    local instance_ip=$2
    local instance_type=$3
    
    echo -e "${YELLOW}📦 Installing SSM Agent on ${instance_type} (${instance_id})...${NC}"
    
    # Create installation script
    cat > /tmp/install-ssm.sh << 'EOF'
#!/bin/bash
export DEBIAN_FRONTEND=noninteractive

# Download and install SSM Agent
cd /tmp
wget -q https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/debian_amd64/amazon-ssm-agent.deb
dpkg -i amazon-ssm-agent.deb

# Enable and start service
systemctl enable amazon-ssm-agent
systemctl start amazon-ssm-agent

# Check status
systemctl status amazon-ssm-agent --no-pager
echo "SSM Agent installation complete"
EOF

    # Try SSH installation first
    if [ -f ~/.ssh/k3s-key ]; then
        echo -e "${YELLOW}Using SSH to install...${NC}"
        scp -i ~/.ssh/k3s-key -o StrictHostKeyChecking=no /tmp/install-ssm.sh ubuntu@$instance_ip:/tmp/
        ssh -i ~/.ssh/k3s-key -o StrictHostKeyChecking=no ubuntu@$instance_ip "sudo bash /tmp/install-ssm.sh"
    else
        echo -e "${YELLOW}Using SSM Send Command...${NC}"
        aws ssm send-command \
            --instance-ids "$instance_id" \
            --document-name "AWS-RunShellScript" \
            --parameters 'commands=["cd /tmp","wget -q https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/debian_amd64/amazon-ssm-agent.deb","dpkg -i amazon-ssm-agent.deb","systemctl enable amazon-ssm-agent","systemctl start amazon-ssm-agent","systemctl status amazon-ssm-agent --no-pager"]' \
            --output text
    fi
    
    echo -e "${GREEN}✅ SSM Agent installed on ${instance_type}${NC}"
}

# Install on K3s instance
if [ "$K3S_INSTANCE" != "None	None" ]; then
    K3S_ID=$(echo $K3S_INSTANCE | cut -f1)
    K3S_IP=$(echo $K3S_INSTANCE | cut -f2)
    install_ssm_on_instance "$K3S_ID" "$K3S_IP" "K3s"
else
    echo -e "${RED}❌ K3s instance not found${NC}"
fi

# Install on GitHub runner instance
if [ "$RUNNER_INSTANCE" != "None	None" ]; then
    RUNNER_ID=$(echo $RUNNER_INSTANCE | cut -f1)
    RUNNER_IP=$(echo $RUNNER_INSTANCE | cut -f2)
    install_ssm_on_instance "$RUNNER_ID" "$RUNNER_IP" "GitHub Runner"
else
    echo -e "${RED}❌ GitHub Runner instance not found${NC}"
fi

echo -e "${GREEN}🎉 SSM Agent installation complete!${NC}"
echo -e "${YELLOW}💡 Wait 2-3 minutes, then check AWS Console → Systems Manager → Fleet Manager${NC}"