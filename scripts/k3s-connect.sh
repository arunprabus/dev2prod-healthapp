#!/bin/bash

# K3s Connection Helper Script
# Usage: ./k3s-connect.sh <environment> [action]
# Environment: dev, test, prod, monitoring
# Action: ssh, kubectl, session-manager (default: kubectl)

set -e

ENVIRONMENT=${1:-dev}
ACTION=${2:-kubectl}

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🔗 K3s Connection Helper${NC}"
echo -e "${YELLOW}Environment: ${ENVIRONMENT}${NC}"
echo -e "${YELLOW}Action: ${ACTION}${NC}"

# Get K3s instance information
get_k3s_info() {
    local env=$1
    
    # Map environment to network tier
    case $env in
        "dev"|"test")
            NETWORK_TIER="lower"
            ;;
        "prod")
            NETWORK_TIER="higher"
            ;;
        "monitoring")
            NETWORK_TIER="monitoring"
            ;;
        *)
            echo -e "${RED}❌ Invalid environment: $env${NC}"
            echo "Valid environments: dev, test, prod, monitoring"
            exit 1
            ;;
    esac
    
    # Get instance information using AWS CLI
    INSTANCE_INFO=$(aws ec2 describe-instances \
        --filters "Name=tag:Name,Values=health-app-${NETWORK_TIER}-k3s-node-v2" \
                  "Name=instance-state-name,Values=running" \
        --query 'Reservations[0].Instances[0].[InstanceId,PublicIpAddress,PrivateIpAddress]' \
        --output text 2>/dev/null)
    
    if [ "$INSTANCE_INFO" = "None	None	None" ] || [ -z "$INSTANCE_INFO" ]; then
        echo -e "${RED}❌ No running K3s instance found for environment: $env${NC}"
        echo "Make sure the infrastructure is deployed and running."
        exit 1
    fi
    
    INSTANCE_ID=$(echo $INSTANCE_INFO | cut -f1)
    PUBLIC_IP=$(echo $INSTANCE_INFO | cut -f2)
    PRIVATE_IP=$(echo $INSTANCE_INFO | cut -f3)
    
    echo -e "${GREEN}✅ Found K3s instance:${NC}"
    echo -e "  Instance ID: ${INSTANCE_ID}"
    echo -e "  Public IP: ${PUBLIC_IP}"
    echo -e "  Private IP: ${PRIVATE_IP}"
}

# SSH connection
connect_ssh() {
    echo -e "${GREEN}🔐 Connecting via SSH...${NC}"
    
    # Try to find the SSH key
    SSH_KEY=""
    if [ -f ~/.ssh/k3s-key ]; then
        SSH_KEY=~/.ssh/k3s-key
    elif [ -f ~/.ssh/aws-key ]; then
        SSH_KEY=~/.ssh/aws-key
    elif [ -f ~/.ssh/id_rsa ]; then
        SSH_KEY=~/.ssh/id_rsa
    else
        echo -e "${RED}❌ SSH key not found${NC}"
        echo "Expected locations: ~/.ssh/k3s-key, ~/.ssh/aws-key, ~/.ssh/id_rsa"
        exit 1
    fi
    
    echo -e "${YELLOW}Using SSH key: ${SSH_KEY}${NC}"
    ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ubuntu@$PUBLIC_IP
}

# Session Manager connection
connect_session_manager() {
    echo -e "${GREEN}🖥️ Connecting via Session Manager...${NC}"
    
    # Check if Session Manager plugin is installed
    if ! command -v session-manager-plugin &> /dev/null; then
        echo -e "${RED}❌ Session Manager plugin not installed${NC}"
        echo "Install it from: https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html"
        exit 1
    fi
    
    aws ssm start-session --target $INSTANCE_ID
}

# kubectl connection
connect_kubectl() {
    echo -e "${GREEN}☸️ Setting up kubectl connection...${NC}"
    
    # Check if kubeconfig secret exists in GitHub (for CI/CD context)
    if [ -n "$KUBECONFIG_DEV" ] || [ -n "$KUBECONFIG_TEST" ] || [ -n "$KUBECONFIG_PROD" ] || [ -n "$KUBECONFIG_MONITORING" ]; then
        echo -e "${GREEN}📋 Using kubeconfig from GitHub secrets${NC}"
        
        case $ENVIRONMENT in
            "dev")
                echo "$KUBECONFIG_DEV" | base64 -d > /tmp/kubeconfig-$ENVIRONMENT
                ;;
            "test")
                echo "$KUBECONFIG_TEST" | base64 -d > /tmp/kubeconfig-$ENVIRONMENT
                ;;
            "prod")
                echo "$KUBECONFIG_PROD" | base64 -d > /tmp/kubeconfig-$ENVIRONMENT
                ;;
            "monitoring")
                echo "$KUBECONFIG_MONITORING" | base64 -d > /tmp/kubeconfig-$ENVIRONMENT
                ;;
        esac
        
        export KUBECONFIG=/tmp/kubeconfig-$ENVIRONMENT
        echo -e "${GREEN}✅ Kubeconfig ready for $ENVIRONMENT${NC}"
        
    else
        echo -e "${YELLOW}📥 Downloading kubeconfig from K3s instance...${NC}"
        
        # Create temporary kubeconfig
        TEMP_KUBECONFIG="/tmp/kubeconfig-$ENVIRONMENT"
        
        # Try SSH first, then Session Manager
        SSH_KEY=""
        if [ -f ~/.ssh/k3s-key ]; then
            SSH_KEY=~/.ssh/k3s-key
        elif [ -f ~/.ssh/aws-key ]; then
            SSH_KEY=~/.ssh/aws-key
        fi
        
        if [ -n "$SSH_KEY" ]; then
            echo -e "${YELLOW}Using SSH to download kubeconfig...${NC}"
            scp -i "$SSH_KEY" -o StrictHostKeyChecking=no ubuntu@$PUBLIC_IP:/etc/rancher/k3s/k3s.yaml "$TEMP_KUBECONFIG"
            
            # Update server IP in kubeconfig
            sed -i "s/127.0.0.1/$PUBLIC_IP/g" "$TEMP_KUBECONFIG"
            
        else
            echo -e "${YELLOW}Using Session Manager to download kubeconfig...${NC}"
            # Create a temporary script to download kubeconfig via Session Manager
            cat > /tmp/download-kubeconfig.sh << 'EOF'
#!/bin/bash
sudo cat /etc/rancher/k3s/k3s.yaml
EOF
            
            # Execute via Session Manager and capture output
            aws ssm send-command \
                --instance-ids "$INSTANCE_ID" \
                --document-name "AWS-RunShellScript" \
                --parameters 'commands=["sudo cat /etc/rancher/k3s/k3s.yaml"]' \
                --query 'Command.CommandId' \
                --output text > /tmp/command-id
            
            sleep 5
            
            aws ssm get-command-invocation \
                --command-id "$(cat /tmp/command-id)" \
                --instance-id "$INSTANCE_ID" \
                --query 'StandardOutputContent' \
                --output text > "$TEMP_KUBECONFIG"
            
            # Update server IP in kubeconfig
            sed -i "s/127.0.0.1/$PUBLIC_IP/g" "$TEMP_KUBECONFIG"
        fi
        
        export KUBECONFIG="$TEMP_KUBECONFIG"
        echo -e "${GREEN}✅ Kubeconfig downloaded and configured${NC}"
    fi
    
    # Test connection
    echo -e "${YELLOW}🧪 Testing kubectl connection...${NC}"
    if kubectl cluster-info &>/dev/null; then
        echo -e "${GREEN}✅ kubectl connection successful!${NC}"
        kubectl get nodes
        echo ""
        echo -e "${GREEN}📋 Available namespaces:${NC}"
        kubectl get namespaces
        echo ""
        echo -e "${YELLOW}💡 To use this kubeconfig:${NC}"
        echo -e "  export KUBECONFIG=$KUBECONFIG"
        echo -e "  kubectl get pods -n health-app-$ENVIRONMENT"
    else
        echo -e "${RED}❌ kubectl connection failed${NC}"
        exit 1
    fi
}

# Main execution
get_k3s_info "$ENVIRONMENT"

case $ACTION in
    "ssh")
        connect_ssh
        ;;
    "session-manager"|"ssm")
        connect_session_manager
        ;;
    "kubectl"|"k8s")
        connect_kubectl
        ;;
    *)
        echo -e "${RED}❌ Invalid action: $ACTION${NC}"
        echo "Valid actions: ssh, session-manager (ssm), kubectl (k8s)"
        exit 1
        ;;
esac