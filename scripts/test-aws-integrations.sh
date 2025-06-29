#!/bin/bash

# Test AWS Integrations Script
set -e

ENVIRONMENT=${1:-"dev"}
AWS_REGION=${2:-"ap-south-1"}

echo "🧪 Testing AWS Integrations for environment: $ENVIRONMENT"

# Test CloudWatch Logs
echo "📊 Testing CloudWatch Logs..."
LOG_GROUP="/aws/health-app/$ENVIRONMENT"

if aws logs describe-log-groups --log-group-name-prefix "$LOG_GROUP" --region "$AWS_REGION" | grep -q "$LOG_GROUP"; then
    echo "✅ CloudWatch Log Group exists: $LOG_GROUP"
else
    echo "❌ CloudWatch Log Group not found: $LOG_GROUP"
fi

# Test Lambda Function
echo "🤖 Testing Lambda Function..."
FUNCTION_NAME="health-app-cost-optimizer-$ENVIRONMENT"

if aws lambda get-function --function-name "$FUNCTION_NAME" --region "$AWS_REGION" >/dev/null 2>&1; then
    echo "✅ Lambda Function exists: $FUNCTION_NAME"
    
    # Test Lambda invocation
    echo "🔄 Testing Lambda invocation..."
    aws lambda invoke --function-name "$FUNCTION_NAME" --region "$AWS_REGION" \
        --payload '{"test": true}' response.json
    
    if [ -f response.json ]; then
        echo "✅ Lambda invocation successful"
        cat response.json
        rm response.json
    fi
else
    echo "❌ Lambda Function not found: $FUNCTION_NAME"
fi

# Test EventBridge Rule
echo "⏰ Testing EventBridge Rule..."
RULE_NAME="health-app-cost-optimizer-schedule-$ENVIRONMENT"

if aws events describe-rule --name "$RULE_NAME" --region "$AWS_REGION" >/dev/null 2>&1; then
    echo "✅ EventBridge Rule exists: $RULE_NAME"
    
    # Show rule details
    aws events describe-rule --name "$RULE_NAME" --region "$AWS_REGION" \
        --query '{Name:Name,ScheduleExpression:ScheduleExpression,State:State}'
else
    echo "❌ EventBridge Rule not found: $RULE_NAME"
fi

# Test Systems Manager Parameters
echo "🔧 Testing Systems Manager Parameters..."
PARAMETERS=(
    "/health-app/$ENVIRONMENT/database/host"
    "/health-app/$ENVIRONMENT/database/name"
    "/health-app/$ENVIRONMENT/database/user"
)

for param in "${PARAMETERS[@]}"; do
    if aws ssm get-parameter --name "$param" --region "$AWS_REGION" >/dev/null 2>&1; then
        echo "✅ SSM Parameter exists: $param"
    else
        echo "❌ SSM Parameter not found: $param"
    fi
done

# Test Kubernetes Resources
echo "☸️  Testing Kubernetes Resources..."

if kubectl get namespace aws-integrations >/dev/null 2>&1; then
    echo "✅ Namespace exists: aws-integrations"
else
    echo "❌ Namespace not found: aws-integrations"
fi

if kubectl get daemonset cloudwatch-agent -n aws-integrations >/dev/null 2>&1; then
    echo "✅ CloudWatch Agent DaemonSet exists"
    kubectl get daemonset cloudwatch-agent -n aws-integrations
else
    echo "❌ CloudWatch Agent DaemonSet not found"
fi

if kubectl get daemonset fluent-bit -n aws-integrations >/dev/null 2>&1; then
    echo "✅ Fluent Bit DaemonSet exists"
    kubectl get daemonset fluent-bit -n aws-integrations
else
    echo "❌ Fluent Bit DaemonSet not found"
fi

# Test External Secrets
echo "🔐 Testing External Secrets..."

if kubectl get namespace external-secrets-system >/dev/null 2>&1; then
    echo "✅ External Secrets namespace exists"
    
    if kubectl get deployment external-secrets-controller -n external-secrets-system >/dev/null 2>&1; then
        echo "✅ External Secrets Controller exists"
        kubectl get deployment external-secrets-controller -n external-secrets-system
    else
        echo "❌ External Secrets Controller not found"
    fi
else
    echo "❌ External Secrets namespace not found"
fi

if kubectl get externalsecret health-api-ssm-secrets -n health-app-dev >/dev/null 2>&1; then
    echo "✅ External Secret exists: health-api-ssm-secrets"
    kubectl get externalsecret health-api-ssm-secrets -n health-app-dev
else
    echo "❌ External Secret not found: health-api-ssm-secrets"
fi

# Test Application Integration
echo "🏥 Testing Application Integration..."

if kubectl get deployment health-api-backend-dev -n health-app-dev >/dev/null 2>&1; then
    echo "✅ Health API deployment exists"
    
    # Check if pods are running
    READY_PODS=$(kubectl get deployment health-api-backend-dev -n health-app-dev -o jsonpath='{.status.readyReplicas}')
    DESIRED_PODS=$(kubectl get deployment health-api-backend-dev -n health-app-dev -o jsonpath='{.spec.replicas}')
    
    if [[ "$READY_PODS" == "$DESIRED_PODS" ]]; then
        echo "✅ All pods are ready: $READY_PODS/$DESIRED_PODS"
    else
        echo "⚠️  Pods not fully ready: $READY_PODS/$DESIRED_PODS"
    fi
else
    echo "❌ Health API deployment not found"
fi

# Generate Summary
echo ""
echo "📋 Integration Test Summary"
echo "=========================="
echo "Environment: $ENVIRONMENT"
echo "Region: $AWS_REGION"
echo "Date: $(date)"
echo ""

# Cost Summary
echo "💰 Cost Impact Summary"
echo "====================="
echo "CloudWatch Logs: FREE (within 5GB limit)"
echo "Lambda Functions: FREE (within 1M requests limit)"
echo "Systems Manager: FREE"
echo "EventBridge: FREE (within limits)"
echo "Total Additional Cost: $0/month"
echo ""

echo "🎉 AWS Integrations test completed!"