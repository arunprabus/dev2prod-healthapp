#!/bin/bash
# Get real token from K3s cluster
INSTANCE_ID="i-06a5e7f952d21994b"
REGION="ap-south-1"

echo "Getting real token from K3s cluster..."

aws ssm send-command \
    --instance-ids $INSTANCE_ID \
    --document-name "AWS-RunShellScript" \
    --parameters 'commands=["sudo k3s kubectl create namespace gha-access || true","sudo k3s kubectl create serviceaccount gha-deployer -n gha-access || true","TOKEN=$(sudo k3s kubectl create token gha-deployer -n gha-access --duration=24h)","echo \"Real token: $TOKEN\"","aws ssm put-parameter --name \"/dev/health-app/kubeconfig/token\" --value \"$TOKEN\" --type \"SecureString\" --overwrite --region ap-south-1"]' \
    --region $REGION \
    --output text \
    --query 'Command.CommandId'