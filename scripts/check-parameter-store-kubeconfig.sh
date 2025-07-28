#!/bin/bash

# Check Parameter Store Kubeconfig Status and Setup
# Usage: ./check-parameter-store-kubeconfig.sh [environment]

set -e

ENVIRONMENT=${1:-"all"}
REGION="ap-south-1"

echo "🔍 Checking Parameter Store Kubeconfig Status"
echo "=============================================="

check_environment() {
    local env=$1
    echo ""
    echo "📋 Environment: $env"
    echo "-------------------"
    
    # Check if parameters exist
    echo "🔍 Checking Parameter Store parameters..."
    
    local server_param="/$env/health-app/kubeconfig/server"
    local token_param="/$env/health-app/kubeconfig/token"
    local cluster_param="/$env/health-app/kubeconfig/cluster-name"
    
    # Check server parameter
    SERVER=$(aws ssm get-parameter \
        --name "$server_param" \
        --region $REGION \
        --query 'Parameter.Value' \
        --output text 2>/dev/null || echo "NOT_FOUND")
    
    # Check token parameter
    TOKEN_EXISTS=$(aws ssm get-parameter \
        --name "$token_param" \
        --region $REGION \
        --query 'Parameter.Name' \
        --output text 2>/dev/null || echo "NOT_FOUND")
    
    # Check cluster name parameter
    CLUSTER_NAME=$(aws ssm get-parameter \
        --name "$cluster_param" \
        --region $REGION \
        --query 'Parameter.Value' \
        --output text 2>/dev/null || echo "NOT_FOUND")
    
    # Display results
    if [ "$SERVER" != "NOT_FOUND" ]; then
        echo "✅ Server: $SERVER"
    else
        echo "❌ Server parameter not found: $server_param"
    fi
    
    if [ "$TOKEN_EXISTS" != "NOT_FOUND" ]; then
        echo "✅ Token: Parameter exists (encrypted)"
    else
        echo "❌ Token parameter not found: $token_param"
    fi
    
    if [ "$CLUSTER_NAME" != "NOT_FOUND" ]; then
        echo "✅ Cluster Name: $CLUSTER_NAME"
    else
        echo "❌ Cluster Name parameter not found: $cluster_param"
    fi
    
    # Check if infrastructure exists
    echo ""
    echo "🏗️ Checking infrastructure status..."
    INSTANCE_ID=$(aws ec2 describe-instances \
        --filters "Name=tag:Name,Values=health-app-lower-$env" "Name=instance-state-name,Values=running" \
        --query 'Reservations[0].Instances[0].InstanceId' \
        --output text 2>/dev/null || echo "None")
    
    if [ "$INSTANCE_ID" != "None" ]; then
        echo "✅ Infrastructure: Running (Instance: $INSTANCE_ID)"
        
        # Get public IP
        PUBLIC_IP=$(aws ec2 describe-instances \
            --instance-ids $INSTANCE_ID \
            --query 'Reservations[0].Instances[0].PublicIpAddress' \
            --output text 2>/dev/null || echo "Unknown")
        echo "📡 Public IP: $PUBLIC_IP"
        
        # Check SSM agent status
        SSM_STATUS=$(aws ssm describe-instance-information \
            --filters "Key=InstanceIds,Values=$INSTANCE_ID" \
            --query 'InstanceInformationList[0].PingStatus' \
            --output text 2>/dev/null || echo "Unknown")
        echo "🔧 SSM Agent: $SSM_STATUS"
    else
        echo "❌ Infrastructure: No running instances found"
    fi
    
    # Overall status
    echo ""
    if [ "$SERVER" != "NOT_FOUND" ] && [ "$TOKEN_EXISTS" != "NOT_FOUND" ]; then
        echo "🎉 Status: READY - Kubeconfig available in Parameter Store"
        echo "📝 To use: ./scripts/get-kubeconfig-from-parameter-store.sh $env"
    elif [ "$INSTANCE_ID" != "None" ]; then
        echo "⚠️  Status: SETUP NEEDED - Infrastructure exists but kubeconfig not in Parameter Store"
        echo "📝 To setup: ./scripts/setup-parameter-store-kubeconfig.sh $env"
    else
        echo "❌ Status: INFRASTRUCTURE MISSING - Deploy infrastructure first"
        echo "📝 To deploy: Run GitHub Actions workflow or terraform apply"
    fi
}

# Main execution
if [ "$ENVIRONMENT" = "all" ]; then
    echo "Checking all environments..."
    for env in dev test prod; do
        check_environment $env
    done
else
    check_environment $ENVIRONMENT
fi

echo ""
echo "🚀 Quick Actions:"
echo "=================="
echo "1. Setup Parameter Store for dev:  ./scripts/setup-parameter-store-kubeconfig.sh dev"
echo "2. Get kubeconfig for dev:         ./scripts/get-kubeconfig-from-parameter-store.sh dev"
echo "3. Test cluster connection:        ./scripts/test-lower-deployment.sh"
echo "4. Check all parameters:           aws ssm get-parameters-by-path --path '/dev/health-app/' --region ap-south-1"
echo ""
echo "📚 Documentation: docs/PARAMETER-STORE-KUBECONFIG.md"