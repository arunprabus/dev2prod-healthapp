#!/bin/bash

# Download Kubeconfig from GitHub Secrets
# Usage: ./download-kubeconfig.sh <environment>

ENVIRONMENT=${1:-dev}
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}📥 Downloading kubeconfig for ${ENVIRONMENT}${NC}"

# Check if running in GitHub Actions
if [ -n "$GITHUB_ACTIONS" ]; then
    echo -e "${YELLOW}Running in GitHub Actions - using secrets directly${NC}"
    
    case $ENVIRONMENT in
        "dev")
            echo "$KUBECONFIG_DEV" | base64 -d > kubeconfig-${ENVIRONMENT}.yaml
            ;;
        "test")
            echo "$KUBECONFIG_TEST" | base64 -d > kubeconfig-${ENVIRONMENT}.yaml
            ;;
        "prod")
            echo "$KUBECONFIG_PROD" | base64 -d > kubeconfig-${ENVIRONMENT}.yaml
            ;;
        "monitoring")
            echo "$KUBECONFIG_MONITORING" | base64 -d > kubeconfig-${ENVIRONMENT}.yaml
            ;;
        *)
            echo -e "${RED}❌ Invalid environment: $ENVIRONMENT${NC}"
            exit 1
            ;;
    esac
else
    echo -e "${RED}❌ This script requires GitHub Actions environment${NC}"
    echo -e "${YELLOW}💡 Use the Kubeconfig Access workflow instead:${NC}"
    echo "   1. Go to Actions → Kubeconfig Access"
    echo "   2. Select environment: $ENVIRONMENT"
    echo "   3. Select action: download"
    echo "   4. Run workflow"
    exit 1
fi

if [ -f "kubeconfig-${ENVIRONMENT}.yaml" ]; then
    echo -e "${GREEN}✅ Kubeconfig downloaded: kubeconfig-${ENVIRONMENT}.yaml${NC}"
    
    # Test connection
    export KUBECONFIG="$PWD/kubeconfig-${ENVIRONMENT}.yaml"
    echo -e "${YELLOW}🧪 Testing connection...${NC}"
    
    if timeout 30 kubectl get nodes --request-timeout=20s 2>/dev/null; then
        echo -e "${GREEN}✅ Connection successful!${NC}"
        echo -e "${YELLOW}🐳 Checking pods...${NC}"
        kubectl get pods -A --field-selector=status.phase=Running | head -10
    else
        echo -e "${YELLOW}⚠️ Connection test failed (cluster may still be initializing)${NC}"
    fi
    
    echo -e "${YELLOW}🚀 To use locally:${NC}"
    echo "export KUBECONFIG=\$PWD/kubeconfig-${ENVIRONMENT}.yaml"
    echo "kubectl get nodes"
else
    echo -e "${RED}❌ Failed to download kubeconfig${NC}"
    exit 1
fi