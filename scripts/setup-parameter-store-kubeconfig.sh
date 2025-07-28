#!/bin/bash

# Setup Parameter Store with Kubeconfig Data
# Usage: ./setup-parameter-store-kubeconfig.sh <environment>

set -e

ENVIRONMENT=${1}
REGION="ap-south-1"

if [ -z "$ENVIRONMENT" ]; then
    echo "❌ Error: Environment is required"
    echo "Usage: $0 <environment>"
    echo "Example: $0 dev"
    exit 1
fi

echo "🔧 Setting up Parameter Store for $ENVIRONMENT environment..."

# Check if infrastructure is deployed
echo "📋 Checking infrastructure status..."
INSTANCE_ID=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=health-app-lower-$ENVIRONMENT" "Name=instance-state-name,Values=running" \
    --query 'Reservations[0].Instances[0].InstanceId' \
    --output text 2>/dev/null || echo "None")

if [ "$INSTANCE_ID" = "None" ]; then
    echo "❌ Error: No running instance found for environment $ENVIRONMENT"
    echo "   Please deploy the infrastructure first"
    exit 1
fi

echo "✅ Found instance: $INSTANCE_ID"

# Get instance public IP
PUBLIC_IP=$(aws ec2 describe-instances \
    --instance-ids $INSTANCE_ID \
    --query 'Reservations[0].Instances[0].PublicIpAddress' \
    --output text)

echo "📡 Instance IP: $PUBLIC_IP"

# Wait for SSM agent to be ready
echo "⏳ Waiting for SSM agent to be ready..."
for i in {1..10}; do
    if aws ssm describe-instance-information \
        --filters "Key=InstanceIds,Values=$INSTANCE_ID" \
        --query 'InstanceInformationList[0].PingStatus' \
        --output text 2>/dev/null | grep -q "Online"; then
        echo "✅ SSM agent is online"
        break
    fi
    echo "   Attempt $i/10: SSM agent not ready, waiting 30s..."
    sleep 30
done

# Execute commands on the instance to setup kubeconfig in Parameter Store
echo "🔑 Setting up kubeconfig in Parameter Store..."

# Create the command to run on the instance
COMMAND='#!/bin/bash
set -e

ENVIRONMENT="'$ENVIRONMENT'"
REGION="ap-south-1"

# Wait for K3s to be ready
echo "Waiting for K3s to be ready..."
for i in {1..20}; do
    if sudo k3s kubectl get nodes > /dev/null 2>&1; then
        echo "K3s is ready"
        break
    fi
    echo "Attempt $i/20: K3s not ready, waiting 30s..."
    sleep 30
done

# Create namespace and service account if not exists
echo "Setting up service account..."
sudo k3s kubectl create namespace gha-access || true
sudo k3s kubectl create serviceaccount gha-deployer -n gha-access || true

# Create role and binding
sudo k3s kubectl create role gha-role --verb=get,list,watch,create,update,patch,delete --resource=pods,services,deployments,namespaces -n gha-access || true
sudo k3s kubectl create rolebinding gha-rolebinding --role=gha-role --serviceaccount=gha-access:gha-deployer -n gha-access || true

# Generate token
echo "Generating service account token..."
TOKEN=$(sudo k3s kubectl create token gha-deployer -n gha-access --duration=24h)

if [ -n "$TOKEN" ]; then
    PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
    
    # Store in Parameter Store
    echo "Storing kubeconfig data in Parameter Store..."
    aws ssm put-parameter \
        --name "/$ENVIRONMENT/health-app/kubeconfig/server" \
        --value "https://$PUBLIC_IP:6443" \
        --type "String" \
        --overwrite \
        --region $REGION
    
    aws ssm put-parameter \
        --name "/$ENVIRONMENT/health-app/kubeconfig/token" \
        --value "$TOKEN" \
        --type "SecureString" \
        --overwrite \
        --region $REGION
    
    aws ssm put-parameter \
        --name "/$ENVIRONMENT/health-app/kubeconfig/cluster-name" \
        --value "k3s-cluster" \
        --type "String" \
        --overwrite \
        --region $REGION
    
    echo "SUCCESS: Kubeconfig data stored in Parameter Store"
else
    echo "ERROR: Failed to generate token"
    exit 1
fi'

# Execute the command on the instance
echo "📤 Executing setup command on instance..."
aws ssm send-command \
    --instance-ids $INSTANCE_ID \
    --document-name "AWS-RunShellScript" \
    --parameters "commands=[\"$COMMAND\"]" \
    --region $REGION \
    --output text \
    --query 'Command.CommandId' > /tmp/command-id.txt

COMMAND_ID=$(cat /tmp/command-id.txt)
echo "📋 Command ID: $COMMAND_ID"

# Wait for command to complete
echo "⏳ Waiting for command to complete..."
for i in {1..20}; do
    STATUS=$(aws ssm get-command-invocation \
        --command-id $COMMAND_ID \
        --instance-id $INSTANCE_ID \
        --region $REGION \
        --query 'Status' \
        --output text 2>/dev/null || echo "InProgress")
    
    if [ "$STATUS" = "Success" ]; then
        echo "✅ Command completed successfully"
        break
    elif [ "$STATUS" = "Failed" ]; then
        echo "❌ Command failed"
        aws ssm get-command-invocation \
            --command-id $COMMAND_ID \
            --instance-id $INSTANCE_ID \
            --region $REGION \
            --query 'StandardErrorContent' \
            --output text
        exit 1
    fi
    
    echo "   Attempt $i/20: Status is $STATUS, waiting 30s..."
    sleep 30
done

# Verify parameters were created
echo "🔍 Verifying Parameter Store setup..."
aws ssm get-parameters-by-path \
    --path "/$ENVIRONMENT/health-app/kubeconfig/" \
    --region $REGION \
    --query 'Parameters[*].[Name,Type]' \
    --output table

echo "✅ Parameter Store setup complete!"
echo ""
echo "🚀 To test the kubeconfig:"
echo "./scripts/get-kubeconfig-from-parameter-store.sh $ENVIRONMENT"