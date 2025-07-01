#!/bin/bash

# Complete Deployment Flow Test Script
set -e

ENVIRONMENT=${1:-"dev"}
CLUSTER_IP=${2}

echo "🧪 Testing Complete Deployment Flow for: $ENVIRONMENT"

if [[ -z "$CLUSTER_IP" ]]; then
    echo "❌ Usage: $0 <environment> <cluster-ip>"
    echo "Example: $0 dev 1.2.3.4"
    exit 1
fi

# Test 1: Infrastructure Verification
echo "🏗️ Test 1: Infrastructure Verification"
echo "=================================="

# Check EC2 instance
if aws ec2 describe-instances --filters "Name=tag:Environment,Values=$ENVIRONMENT" "Name=instance-state-name,Values=running" --query 'Reservations[].Instances[].InstanceId' --output text | grep -q "i-"; then
    echo "✅ EC2 instance running"
else
    echo "❌ EC2 instance not found or not running"
fi

# Check RDS
if aws rds describe-db-instances --db-instance-identifier "health-app-db-$ENVIRONMENT" --query 'DBInstances[0].DBInstanceStatus' --output text 2>/dev/null | grep -q "available"; then
    echo "✅ RDS database available"
else
    echo "❌ RDS database not available"
fi

# Test 2: K8s Cluster Connection
echo ""
echo "☸️  Test 2: K8s Cluster Connection"
echo "================================"

# Test SSH connection
if ssh -i ~/.ssh/aws-key -o ConnectTimeout=10 -o StrictHostKeyChecking=no ubuntu@$CLUSTER_IP "echo 'SSH connection successful'" 2>/dev/null; then
    echo "✅ SSH connection to cluster successful"
    
    # Test K3s status
    if ssh -i ~/.ssh/aws-key -o StrictHostKeyChecking=no ubuntu@$CLUSTER_IP "sudo systemctl is-active k3s" 2>/dev/null | grep -q "active"; then
        echo "✅ K3s service is running"
    else
        echo "❌ K3s service not running"
    fi
    
    # Test K3s nodes
    if ssh -i ~/.ssh/aws-key -o StrictHostKeyChecking=no ubuntu@$CLUSTER_IP "sudo k3s kubectl get nodes" 2>/dev/null | grep -q "Ready"; then
        echo "✅ K3s nodes are ready"
    else
        echo "❌ K3s nodes not ready"
    fi
else
    echo "❌ SSH connection failed"
fi

# Test 3: Kubeconfig Generation
echo ""
echo "🔧 Test 3: Kubeconfig Generation"
echo "==============================="

if [[ -f "scripts/setup-kubeconfig.sh" ]]; then
    echo "✅ Kubeconfig setup script exists"
    
    # Generate kubeconfig
    if ./scripts/setup-kubeconfig.sh $ENVIRONMENT $CLUSTER_IP >/dev/null 2>&1; then
        echo "✅ Kubeconfig generated successfully"
        
        # Test kubeconfig
        if KUBECONFIG=~/.kube/config-$ENVIRONMENT kubectl cluster-info --request-timeout=10s >/dev/null 2>&1; then
            echo "✅ Kubeconfig connection working"
        else
            echo "❌ Kubeconfig connection failed"
        fi
    else
        echo "❌ Kubeconfig generation failed"
    fi
else
    echo "❌ Kubeconfig setup script not found"
fi

# Test 4: Application Deployment Check
echo ""
echo "🏥 Test 4: Application Deployment"
echo "==============================="

if [[ -f ~/.kube/config-$ENVIRONMENT ]]; then
    export KUBECONFIG=~/.kube/config-$ENVIRONMENT
    
    # Check namespace
    if kubectl get namespace health-app-$ENVIRONMENT >/dev/null 2>&1; then
        echo "✅ Application namespace exists"
        
        # Check deployments
        if kubectl get deployment -n health-app-$ENVIRONMENT >/dev/null 2>&1; then
            DEPLOYMENTS=$(kubectl get deployment -n health-app-$ENVIRONMENT --no-headers 2>/dev/null | wc -l)
            if [[ $DEPLOYMENTS -gt 0 ]]; then
                echo "✅ Application deployments found ($DEPLOYMENTS)"
                
                # Check pod status
                READY_PODS=$(kubectl get pods -n health-app-$ENVIRONMENT --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
                TOTAL_PODS=$(kubectl get pods -n health-app-$ENVIRONMENT --no-headers 2>/dev/null | wc -l)
                
                if [[ $READY_PODS -gt 0 ]]; then
                    echo "✅ Application pods running ($READY_PODS/$TOTAL_PODS)"
                else
                    echo "❌ No application pods running"
                fi
            else
                echo "❌ No application deployments found"
            fi
        else
            echo "❌ Cannot access deployments"
        fi
    else
        echo "❌ Application namespace not found"
    fi
else
    echo "❌ Kubeconfig not available for testing"
fi

# Test 5: Service Connectivity
echo ""
echo "🌐 Test 5: Service Connectivity"
echo "============================="

if [[ -f ~/.kube/config-$ENVIRONMENT ]]; then
    export KUBECONFIG=~/.kube/config-$ENVIRONMENT
    
    # Check services
    if kubectl get services -n health-app-$ENVIRONMENT >/dev/null 2>&1; then
        SERVICES=$(kubectl get services -n health-app-$ENVIRONMENT --no-headers 2>/dev/null | wc -l)
        if [[ $SERVICES -gt 0 ]]; then
            echo "✅ Application services found ($SERVICES)"
            
            # Check endpoints
            ENDPOINTS=$(kubectl get endpoints -n health-app-$ENVIRONMENT --no-headers 2>/dev/null | grep -v '<none>' | wc -l)
            if [[ $ENDPOINTS -gt 0 ]]; then
                echo "✅ Service endpoints available ($ENDPOINTS)"
            else
                echo "❌ No service endpoints available"
            fi
        else
            echo "❌ No application services found"
        fi
    else
        echo "❌ Cannot access services"
    fi
fi

# Test 6: AWS Integrations
echo ""
echo "🔧 Test 6: AWS Integrations"
echo "========================="

# Test CloudWatch log group
LOG_GROUP="/aws/health-app/$ENVIRONMENT"
if aws logs describe-log-groups --log-group-name-prefix "$LOG_GROUP" 2>/dev/null | grep -q "$LOG_GROUP"; then
    echo "✅ CloudWatch log group exists"
else
    echo "❌ CloudWatch log group not found"
fi

# Test Lambda function
FUNCTION_NAME="health-app-cost-optimizer-$ENVIRONMENT"
if aws lambda get-function --function-name "$FUNCTION_NAME" >/dev/null 2>&1; then
    echo "✅ Lambda cost optimizer exists"
else
    echo "❌ Lambda cost optimizer not found"
fi

# Test Systems Manager parameters
if aws ssm get-parameter --name "/health-app/$ENVIRONMENT/database/host" >/dev/null 2>&1; then
    echo "✅ Systems Manager parameters exist"
else
    echo "❌ Systems Manager parameters not found"
fi

# Summary
echo ""
echo "📊 Test Summary"
echo "=============="
echo "Environment: $ENVIRONMENT"
echo "Cluster IP: $CLUSTER_IP"
echo "Date: $(date)"
echo ""

# Generate test report
TOTAL_TESTS=15
PASSED_TESTS=0

# Count passed tests (simplified)
if aws ec2 describe-instances --filters "Name=tag:Environment,Values=$ENVIRONMENT" --query 'Reservations[].Instances[].InstanceId' --output text 2>/dev/null | grep -q "i-"; then
    ((PASSED_TESTS++))
fi

echo "🎯 Test Results: $PASSED_TESTS/$TOTAL_TESTS tests passed"

if [[ $PASSED_TESTS -ge 10 ]]; then
    echo "🎉 Deployment flow test: PASSED"
    exit 0
else
    echo "❌ Deployment flow test: FAILED"
    exit 1
fi