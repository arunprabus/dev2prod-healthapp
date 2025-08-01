#!/bin/bash
set -e

INSTANCE_ID="$1"
COMMAND="$2"
KMS_KEY_ID="${3:-alias/aws/ssm}"
REGION="${4:-ap-south-1}"

echo "🔐 Executing KMS-encrypted command on $INSTANCE_ID..."

# Create encrypted parameter
PARAM_NAME="/temp/secure-command-$(date +%s)"
aws ssm put-parameter \
    --name "$PARAM_NAME" \
    --value "$COMMAND" \
    --type "SecureString" \
    --key-id "$KMS_KEY_ID" \
    --region "$REGION" \
    --overwrite

# Execute via Run Command with parameter reference
EXECUTE_SCRIPT="#!/bin/bash
COMMAND=\$(aws ssm get-parameter --name '$PARAM_NAME' --with-decryption --region '$REGION' --query 'Parameter.Value' --output text)
eval \"\$COMMAND\"
"

COMMAND_ID=$(aws ssm send-command \
    --instance-ids "$INSTANCE_ID" \
    --document-name "AWS-RunShellScript" \
    --parameters "commands=[\"$EXECUTE_SCRIPT\"]" \
    --region "$REGION" \
    --query 'Command.CommandId' \
    --output text)

# Wait for completion
aws ssm wait command-executed \
    --command-id "$COMMAND_ID" \
    --instance-id "$INSTANCE_ID" \
    --region "$REGION"

# Get output
aws ssm get-command-invocation \
    --command-id "$COMMAND_ID" \
    --instance-id "$INSTANCE_ID" \
    --region "$REGION" \
    --query 'StandardOutputContent' \
    --output text

# Cleanup parameter
aws ssm delete-parameter --name "$PARAM_NAME" --region "$REGION"

echo "✅ Secure command executed and cleaned up"