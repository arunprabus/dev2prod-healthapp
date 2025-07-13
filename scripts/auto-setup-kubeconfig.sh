#!/bin/bash

# Automated Kubeconfig Setup Script
# Usage: ./auto-setup-kubeconfig.sh <environment> [github-token]

set -e

ENVIRONMENT=${1:-lower}
GITHUB_TOKEN=${2:-$GITHUB_TOKEN}
REPO_NAME=${REPO_NAME:-"arunprabus/dev2prod-healthapp"}

if [ -z "$GITHUB_TOKEN" ]; then
    echo "❌ Error: GitHub token required"
    echo "Usage: $0 <environment> [github-token]"
    echo "Or set GITHUB_TOKEN environment variable"
    exit 1
fi

echo "🔧 Automated kubeconfig setup for $ENVIRONMENT environment..."

# Get cluster IP from AWS
get_cluster_ip() {
    local env=$1
    local tag_name=""
    
    case $env in
        "lower")
            tag_name="health-app-k3s-master-lower"
            ;;
        "higher")
            tag_name="health-app-k3s-master-higher"
            ;;
        "monitoring")
            tag_name="health-app-k3s-master-monitoring"
            ;;
        *)
            echo "❌ Invalid environment: $env"
            exit 1
            ;;
    esac
    
    aws ec2 describe-instances \
        --filters "Name=tag:Name,Values=$tag_name" "Name=instance-state-name,Values=running" \
        --query 'Reservations[0].Instances[0].PublicIpAddress' \
        --output text 2>/dev/null || echo "None"
}

# Download and setup kubeconfig
setup_kubeconfig() {
    local env=$1
    local ip=$2
    
    echo "📥 Downloading kubeconfig from $ip..."
    
    # Download kubeconfig
    scp -i ~/.ssh/k3s-key -o StrictHostKeyChecking=no \
        ubuntu@$ip:/etc/rancher/k3s/k3s.yaml kubeconfig-$env.yaml
    
    # Update server IP
    sed -i "s/127.0.0.1/$ip/" kubeconfig-$env.yaml
    
    # Test connection
    export KUBECONFIG=$PWD/kubeconfig-$env.yaml
    if timeout 30 kubectl get nodes; then
        echo "✅ Connection successful!"
        return 0
    else
        echo "⚠️ Connection test failed but proceeding..."
        return 1
    fi
}

# Create GitHub secret
create_github_secret() {
    local secret_name=$1
    local secret_value=$2
    
    echo "🔐 Creating GitHub secret: $secret_name"
    
    # Get repository public key
    PUBLIC_KEY_RESPONSE=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
        "https://api.github.com/repos/$REPO_NAME/actions/secrets/public-key")
    
    KEY_ID=$(echo "$PUBLIC_KEY_RESPONSE" | jq -r '.key_id')
    
    if [ "$KEY_ID" = "null" ]; then
        echo "❌ Failed to get repository public key"
        return 1
    fi
    
    # Create/update secret (using base64 value directly)
    RESPONSE=$(curl -s -X PUT \
        -H "Authorization: token $GITHUB_TOKEN" \
        -H "Accept: application/vnd.github.v3+json" \
        "https://api.github.com/repos/$REPO_NAME/actions/secrets/$secret_name" \
        -d "{\"encrypted_value\":\"$secret_value\",\"key_id\":\"$KEY_ID\"}")
    
    if echo "$RESPONSE" | grep -q "error"; then
        echo "❌ Failed to create secret: $secret_name"
        echo "$RESPONSE"
        return 1
    else
        echo "✅ Secret created: $secret_name"
        return 0
    fi
}

# Main execution
main() {
    echo "🔍 Getting cluster IP for $ENVIRONMENT..."
    CLUSTER_IP=$(get_cluster_ip "$ENVIRONMENT")
    
    if [ "$CLUSTER_IP" = "None" ] || [ -z "$CLUSTER_IP" ]; then
        echo "❌ No running cluster found for $ENVIRONMENT environment"
        exit 1
    fi
    
    echo "📡 Found cluster at: $CLUSTER_IP"
    
    # Setup kubeconfig
    if setup_kubeconfig "$ENVIRONMENT" "$CLUSTER_IP"; then
        CONNECTION_SUCCESS=true
    else
        CONNECTION_SUCCESS=false
    fi
    
    # Create base64 encoded version
    KUBECONFIG_B64=$(base64 -w 0 kubeconfig-$ENVIRONMENT.yaml)
    
    # Create appropriate GitHub secrets
    case $ENVIRONMENT in
        "lower")
            echo "🔐 Creating secrets for dev and test environments..."
            create_github_secret "KUBECONFIG_DEV" "$KUBECONFIG_B64"
            create_github_secret "KUBECONFIG_TEST" "$KUBECONFIG_B64"
            ;;
        "higher")
            echo "🔐 Creating secret for prod environment..."
            create_github_secret "KUBECONFIG_PROD" "$KUBECONFIG_B64"
            ;;
        "monitoring")
            echo "🔐 Creating secret for monitoring environment..."
            create_github_secret "KUBECONFIG_MONITORING" "$KUBECONFIG_B64"
            ;;
    esac
    
    echo ""
    echo "🎉 Automation completed!"
    echo ""
    echo "📋 Summary:"
    echo "  - Environment: $ENVIRONMENT"
    echo "  - Cluster IP: $CLUSTER_IP"
    echo "  - Connection: $([ "$CONNECTION_SUCCESS" = "true" ] && echo "✅ Working" || echo "⚠️ May need time")"
    echo "  - Secrets: ✅ Created in GitHub"
    echo ""
    echo "🧪 Test with: Actions → Kubeconfig Access → environment: dev → action: test-connection"
}

# Check prerequisites
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI not found"
    exit 1
fi

if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl not found"
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo "❌ jq not found"
    exit 1
fi

if [ ! -f ~/.ssh/k3s-key ]; then
    echo "❌ SSH key not found at ~/.ssh/k3s-key"
    exit 1
fi

# Run main function
main