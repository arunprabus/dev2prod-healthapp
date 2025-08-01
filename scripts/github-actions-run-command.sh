#!/bin/bash
set -e

# GitHub Actions compatible AWS Run Command execution
INSTANCE_ID="$1"
SCRIPT_CONTENT="$2"
REGION="${3:-ap-south-1}"

echo "🚀 Executing via AWS Run Command..."

# Execute command
COMMAND_ID=$(aws ssm send-command \
    --instance-ids "$INSTANCE_ID" \
    --document-name "AWS-RunShellScript" \
    --parameters "commands=[\"$SCRIPT_CONTENT\"]" \
    --region "$REGION" \
    --output text \
    --query 'Command.CommandId')

echo "Command ID: $COMMAND_ID"

# Wait and get output
aws ssm wait command-executed \
    --command-id "$COMMAND_ID" \
    --instance-id "$INSTANCE_ID" \
    --region "$REGION"

# Show output
aws ssm get-command-invocation \
    --command-id "$COMMAND_ID" \
    --instance-id "$INSTANCE_ID" \
    --region "$REGION" \
    --output text \
    --query 'StandardOutputContent'