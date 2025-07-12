#!/bin/bash

# Restart K3s to fix performance issues
# Usage: ./restart-k3s.sh <environment>

ENVIRONMENT=${1:-dev}
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}🔄 Restarting K3s cluster${NC}"

# Map environment to network tier
case $ENVIRONMENT in
    "dev"|"test") NETWORK_TIER="lower" ;;
    "prod") NETWORK_TIER="higher" ;;
    "monitoring") NETWORK_TIER="monitoring" ;;
    *) echo "❌ Invalid environment"; exit 1 ;;
esac

# Get K3s instance IP
K3S_IP=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=health-app-${NETWORK_TIER}-k3s-node" \
              "Name=instance-state-name,Values=running" \
    --query 'Reservations[0].Instances[0].PublicIpAddress' \
    --output text 2>/dev/null)

echo -e "${YELLOW}K3s IP: ${K3S_IP}${NC}"

# Restart K3s service
echo -e "${YELLOW}🔄 Restarting K3s service...${NC}"
ssh -i ~/.ssh/k3s-key -o StrictHostKeyChecking=no ubuntu@$K3S_IP "sudo systemctl restart k3s"

echo -e "${YELLOW}⏳ Waiting for K3s to be ready...${NC}"
sleep 30

# Test connection
echo -e "${YELLOW}🧪 Testing connection...${NC}"
scp -i ~/.ssh/k3s-key -o StrictHostKeyChecking=no ubuntu@$K3S_IP:/etc/rancher/k3s/k3s.yaml /tmp/test-kubeconfig
sed -i "s/127.0.0.1/$K3S_IP/g" /tmp/test-kubeconfig

export KUBECONFIG=/tmp/test-kubeconfig
if timeout 30 kubectl get nodes --request-timeout=20s; then
    echo -e "${GREEN}✅ K3s restart successful!${NC}"
else
    echo -e "${YELLOW}⚠️ Still initializing, try again in a few minutes${NC}"
fi

rm -f /tmp/test-kubeconfig