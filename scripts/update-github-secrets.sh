#!/bin/bash

# Update GitHub Secrets Script
# This script allows updating various GitHub secrets from different sources
# Usage: ./update-github-secrets.sh <action> [options]

set -e

# Default values
GITHUB_TOKEN=${GITHUB_TOKEN:-""}
REPO_NAME=${REPO_NAME:-$(git config --get remote.origin.url | sed 's/.*github.com[:/]\(.*\)\.git/\1/')}
ACTION=${1:-"help"}
SECRET_NAME=${2:-""}
SECRET_VALUE=${3:-""}
SECRET_FILE=${4:-""}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Display help
show_help() {
  echo -e "${BLUE}GitHub Secrets Management Script${NC}"
  echo -e "${YELLOW}Usage:${NC}"
  echo "  $0 <action> [options]"
  echo ""
  echo -e "${YELLOW}Actions:${NC}"
  echo "  list                     - List all secrets in the repository"
  echo "  update <name> <value>    - Update a secret with a direct value"
  echo "  update-file <name> <file>- Update a secret from a file"
  echo "  update-kubeconfig <env> <file> - Update kubeconfig secret for an environment"
  echo "  update-ssh-key           - Update SSH_PUBLIC_KEY and SSH_PRIVATE_KEY from ~/.ssh/k3s-key"
  echo "  update-aws-creds         - Update AWS credentials from environment variables"
  echo "  help                     - Show this help message"
  echo ""
  echo -e "${YELLOW}Examples:${NC}"
  echo "  $0 update MY_SECRET 'secret-value'"
  echo "  $0 update-file API_KEY api-key.txt"
  echo "  $0 update-kubeconfig dev kubeconfig-lower.yaml"
  echo "  $0 update-kubeconfig prod kubeconfig-higher.yaml"
  echo ""
  echo -e "${YELLOW}Notes:${NC}"
  echo "  - Set GITHUB_TOKEN environment variable or pass it as an argument"
  echo "  - REPO_NAME defaults to current git repository or can be set as environment variable"
}

# Check GitHub token
check_token() {
  if [ -z "$GITHUB_TOKEN" ]; then
    echo -e "${RED}❌ Error: GitHub token required${NC}"
    echo "Set GITHUB_TOKEN environment variable or pass it as an argument"
    exit 1
  fi
}

# Get repository public key
get_public_key() {
  echo -e "${YELLOW}🔑 Getting repository public key...${NC}"
  PUBLIC_KEY_RESPONSE=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
    "https://api.github.com/repos/$REPO_NAME/actions/secrets/public-key")

  PUBLIC_KEY=$(echo "$PUBLIC_KEY_RESPONSE" | jq -r '.key')
  KEY_ID=$(echo "$PUBLIC_KEY_RESPONSE" | jq -r '.key_id')

  if [ "$KEY_ID" = "null" ]; then
    echo -e "${RED}❌ Failed to get repository public key${NC}"
    echo "Response: $PUBLIC_KEY_RESPONSE"
    exit 1
  fi

  echo -e "${GREEN}✅ Got public key (ID: $KEY_ID)${NC}"
}

# Encrypt and create secret
create_secret() {
  local secret_name=$1
  local secret_value=$2
  
  echo -e "${YELLOW}🔐 Creating secret: $secret_name${NC}"
  
  # Check if we have the required tools
  if ! command -v python3 &> /dev/null; then
    echo -e "${RED}❌ Python3 not found${NC}"
    return 1
  fi
  
  # Install PyNaCl if not available
  if ! python3 -c "import nacl" 2>/dev/null; then
    echo -e "${YELLOW}📦 Installing PyNaCl...${NC}"
    pip3 install PyNaCl
  fi
  
  # Encrypt the secret
  ENCRYPTED=$(python3 -c "
import base64
import nacl.encoding, nacl.public
public_key = nacl.public.PublicKey(base64.b64decode('$PUBLIC_KEY'), nacl.encoding.RawEncoder())
sealed_box = nacl.public.SealedBox(public_key)
encrypted = sealed_box.encrypt(b'''$secret_value''')
print(base64.b64encode(encrypted).decode())
")
  
  if [ -z "$ENCRYPTED" ]; then
    echo -e "${RED}❌ Failed to encrypt secret${NC}"
    return 1
  fi
  
  # Create secret via GitHub API
  RESPONSE=$(curl -s -X PUT \
    -H "Authorization: token $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github.v3+json" \
    "https://api.github.com/repos/$REPO_NAME/actions/secrets/$secret_name" \
    -d "{\"encrypted_value\":\"$ENCRYPTED\",\"key_id\":\"$KEY_ID\"}")
  
  if echo "$RESPONSE" | grep -q "error\|message"; then
    echo -e "${RED}❌ Failed to create $secret_name${NC}"
    echo "Response: $RESPONSE"
    return 1
  else
    echo -e "${GREEN}✅ Created $secret_name${NC}"
    return 0
  fi
}

# List all secrets
list_secrets() {
  check_token
  
  echo -e "${YELLOW}📋 Listing secrets for $REPO_NAME...${NC}"
  
  RESPONSE=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github.v3+json" \
    "https://api.github.com/repos/$REPO_NAME/actions/secrets")
  
  TOTAL=$(echo "$RESPONSE" | jq -r '.total_count')
  
  if [ "$TOTAL" = "null" ]; then
    echo -e "${RED}❌ Failed to list secrets${NC}"
    echo "Response: $RESPONSE"
    exit 1
  fi
  
  echo -e "${GREEN}✅ Found $TOTAL secrets:${NC}"
  echo "$RESPONSE" | jq -r '.secrets[] | "  - \(.name) (Updated: \(.updated_at))"'
}

# Update a secret with a direct value
update_secret() {
  check_token
  
  if [ -z "$SECRET_NAME" ]; then
    echo -e "${RED}❌ Error: Secret name required${NC}"
    echo "Usage: $0 update <name> <value>"
    exit 1
  fi
  
  if [ -z "$SECRET_VALUE" ]; then
    echo -e "${RED}❌ Error: Secret value required${NC}"
    echo "Usage: $0 update <name> <value>"
    exit 1
  fi
  
  get_public_key
  create_secret "$SECRET_NAME" "$SECRET_VALUE"
}

# Update a secret from a file
update_secret_from_file() {
  check_token
  
  if [ -z "$SECRET_NAME" ]; then
    echo -e "${RED}❌ Error: Secret name required${NC}"
    echo "Usage: $0 update-file <name> <file>"
    exit 1
  fi
  
  if [ -z "$SECRET_VALUE" ]; then
    echo -e "${RED}❌ Error: File path required${NC}"
    echo "Usage: $0 update-file <name> <file>"
    exit 1
  fi
  
  if [ ! -f "$SECRET_VALUE" ]; then
    echo -e "${RED}❌ Error: File not found: $SECRET_VALUE${NC}"
    exit 1
  fi
  
  FILE_CONTENT=$(cat "$SECRET_VALUE")
  
  get_public_key
  create_secret "$SECRET_NAME" "$FILE_CONTENT"
}

# Update kubeconfig secret for an environment
update_kubeconfig() {
  check_token
  
  ENV=${SECRET_NAME:-""}
  KUBECONFIG_FILE=${SECRET_VALUE:-""}
  
  if [ -z "$ENV" ]; then
    echo -e "${RED}❌ Error: Environment required${NC}"
    echo "Usage: $0 update-kubeconfig <env> <file>"
    exit 1
  fi
  
  if [ -z "$KUBECONFIG_FILE" ]; then
    echo -e "${RED}❌ Error: Kubeconfig file required${NC}"
    echo "Usage: $0 update-kubeconfig <env> <file>"
    exit 1
  fi
  
  if [ ! -f "$KUBECONFIG_FILE" ]; then
    echo -e "${RED}❌ Error: Kubeconfig file not found: $KUBECONFIG_FILE${NC}"
    exit 1
  fi
  
  # Create base64 encoded kubeconfig
  KUBECONFIG_B64=$(base64 -w 0 "$KUBECONFIG_FILE")
  
  echo -e "${GREEN}📦 Base64 kubeconfig created ($(echo $KUBECONFIG_B64 | wc -c) characters)${NC}"
  
  get_public_key
  
  # Create the secret
  SECRET_NAME="KUBECONFIG_${ENV^^}"
  create_secret "$SECRET_NAME" "$KUBECONFIG_B64"
  
  # Extract server from kubeconfig
  SERVER=$(grep 'server:' "$KUBECONFIG_FILE" | awk '{print $2}')
  echo -e "${BLUE}ℹ️ Kubeconfig points to: $SERVER${NC}"
}

# Update SSH keys
update_ssh_keys() {
  check_token
  
  SSH_KEY_FILE="${SECRET_NAME:-"$HOME/.ssh/k3s-key"}"
  
  if [ ! -f "$SSH_KEY_FILE" ]; then
    echo -e "${RED}❌ Error: SSH key file not found: $SSH_KEY_FILE${NC}"
    echo "Generate SSH key with: ssh-keygen -t rsa -b 4096 -f ~/.ssh/k3s-key -N \"\" -C \"k3s-cluster-access\""
    exit 1
  fi
  
  if [ ! -f "${SSH_KEY_FILE}.pub" ]; then
    echo -e "${RED}❌ Error: SSH public key file not found: ${SSH_KEY_FILE}.pub${NC}"
    exit 1
  fi
  
  # Read key files
  PRIVATE_KEY=$(cat "$SSH_KEY_FILE")
  PUBLIC_KEY=$(cat "${SSH_KEY_FILE}.pub")
  
  get_public_key
  
  # Create the secrets
  create_secret "SSH_PRIVATE_KEY" "$PRIVATE_KEY"
  create_secret "SSH_PUBLIC_KEY" "$PUBLIC_KEY"
}

# Update AWS credentials
update_aws_creds() {
  check_token
  
  AWS_ACCESS_KEY=${AWS_ACCESS_KEY_ID:-""}
  AWS_SECRET_KEY=${AWS_SECRET_ACCESS_KEY:-""}
  
  if [ -z "$AWS_ACCESS_KEY" ]; then
    echo -e "${RED}❌ Error: AWS_ACCESS_KEY_ID environment variable not set${NC}"
    exit 1
  fi
  
  if [ -z "$AWS_SECRET_KEY" ]; then
    echo -e "${RED}❌ Error: AWS_SECRET_ACCESS_KEY environment variable not set${NC}"
    exit 1
  fi
  
  get_public_key
  
  # Create the secrets
  create_secret "AWS_ACCESS_KEY_ID" "$AWS_ACCESS_KEY"
  create_secret "AWS_SECRET_ACCESS_KEY" "$AWS_SECRET_KEY"
}

# Main execution
case "$ACTION" in
  "list")
    list_secrets
    ;;
  "update")
    update_secret
    ;;
  "update-file")
    update_secret_from_file
    ;;
  "update-kubeconfig")
    update_kubeconfig
    ;;
  "update-ssh-key")
    update_ssh_keys
    ;;
  "update-aws-creds")
    update_aws_creds
    ;;
  "help"|*)
    show_help
    ;;
esac

exit 0