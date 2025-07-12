#!/bin/bash

# Refresh Kubeconfig Secrets
# Usage: ./refresh-kubeconfig.sh <environment>

ENVIRONMENT=${1:-dev}
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}🔄 Refreshing kubeconfig for ${ENVIRONMENT}${NC}"

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

# Download fresh kubeconfig
echo -e "${YELLOW}📥 Downloading fresh kubeconfig...${NC}"
scp -i ~/.ssh/k3s-key -o StrictHostKeyChecking=no ubuntu@$K3S_IP:/etc/rancher/k3s/k3s.yaml /tmp/kubeconfig-fresh

# Update server IP
sed -i "s/127.0.0.1/$K3S_IP/g" /tmp/kubeconfig-fresh

# Test the fresh kubeconfig
export KUBECONFIG=/tmp/kubeconfig-fresh
echo -e "${YELLOW}🧪 Testing fresh kubeconfig...${NC}"

if timeout 30 kubectl get nodes --request-timeout=20s; then
    echo -e "${GREEN}✅ Fresh kubeconfig works!${NC}"
    
    # Save for local use
    cp /tmp/kubeconfig-fresh kubeconfig-${ENVIRONMENT}.yaml
    echo -e "${GREEN}✅ Saved as kubeconfig-${ENVIRONMENT}.yaml${NC}"
    
    echo -e "${YELLOW}🚀 To use:${NC}"
    echo "export KUBECONFIG=\$PWD/kubeconfig-${ENVIRONMENT}.yaml"
    echo "kubectl get nodes"
    
else
    echo -e "${RED}❌ Fresh kubeconfig test failed${NC}"
    echo -e "${YELLOW}🔍 Checking K3s service status...${NC}"
    ssh -i ~/.ssh/k3s-key -o StrictHostKeyChecking=no ubuntu@$K3S_IP "sudo systemctl status k3s --no-pager"
fi

rm -f /tmp/kubeconfig-fresh