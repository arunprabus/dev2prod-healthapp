#!/bin/bash
set -e

INSTANCE_ID="$1"
COMMAND="$2"
REGION="${3:-ap-south-1}"

echo "🚀 Executing command on $INSTANCE_ID via AWS Run Command..."

# Execute command using SSM Run Command
COMMAND_ID=$(aws ssm send-command \
    --instance-ids "$INSTANCE_ID" \
    --document-name "AWS-RunShellScript" \
    --parameters "commands=[\"$COMMAND\"]" \
    --region "$REGION" \
    --query 'Command.CommandId' \
    --output text)

echo "Command ID: $COMMAND_ID"

# Wait for completion
echo "⏳ Waiting for command completion..."
aws ssm wait command-executed \
    --command-id "$COMMAND_ID" \
    --instance-id "$INSTANCE_ID" \
    --region "$REGION"

# Get output
echo "📋 Command output:"
aws ssm get-command-invocation \
    --command-id "$COMMAND_ID" \
    --instance-id "$INSTANCE_ID" \
    --region "$REGION" \
    --query 'StandardOutputContent' \
    --output text

echo "✅ Command executed successfully"