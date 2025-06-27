#!/bin/bash

# Script to set up GitHub environment variables
# Usage: ./setup_environment.sh [environment]

set -e

# Check if GitHub CLI is installed
if ! command -v gh &> /dev/null; then
  echo "Error: GitHub CLI (gh) is not installed."
  echo "Please install it from: https://github.com/cli/cli#installation"
  exit 1
fi

# Check if logged in
if ! gh auth status &> /dev/null; then
  echo "You need to login to GitHub CLI first. Run 'gh auth login'"
  exit 1
fi

# Default values
ENV=${1:-"all"}

# Function to set variables for an environment
setup_env() {
  local env=$1
  local cluster_suffix=$2
  local min_replicas=$3
  local max_replicas=$4
  local kubectl_timeout=$5
  local cleanup_delay=$6
  local lb_wait_time=$7

  echo "Setting up variables for $env environment..."

  # Set environment variables
  gh variable set AWS_REGION --env $env --body "ap-south-1"
  gh variable set EKS_CLUSTER_NAME --env $env --body "health-app-$cluster_suffix"
  gh variable set CONTAINER_REGISTRY --env $env --body "ghcr.io"
  gh variable set REGISTRY_NAMESPACE --env $env --body "arunprabus"
  gh variable set MIN_REPLICAS --env $env --body "$min_replicas"
  gh variable set MAX_REPLICAS --env $env --body "$max_replicas"
  gh variable set KUBECTL_TIMEOUT --env $env --body "${kubectl_timeout}s"
  gh variable set CLEANUP_DELAY --env $env --body "$cleanup_delay"
  gh variable set LB_WAIT_TIME --env $env --body "$lb_wait_time"

  echo "Variables for $env environment set successfully!"
}

# Set global variables
setup_global_vars() {
  echo "Setting up global variables..."

  gh variable set TERRAFORM_VERSION --body "1.6.0"
  gh variable set KUBECTL_VERSION --body "latest"

  echo "Global variables set successfully!"
}

# Main execution
if [[ "$ENV" == "all" ]]; then
  # Create environments if they don't exist
  for e in "dev" "test" "prod"; do
    gh api -X PUT repos/:owner/:repo/environments/$e 2>/dev/null || true
  done

  # Set global variables
  setup_global_vars

  # Set up each environment
  setup_env "dev" "dev" "1" "3" "180" "10" "30"
  setup_env "test" "test" "2" "5" "240" "20" "45"
  setup_env "prod" "prod" "3" "10" "300" "30" "60"

  echo "All environments configured successfully!"
else
  # Validate environment
  if [[ "$ENV" != "dev" && "$ENV" != "test" && "$ENV" != "prod" ]]; then
    echo "Invalid environment. Use 'dev', 'test', 'prod', or 'all'."
    exit 1
  fi

  # Create environment if it doesn't exist
  gh api -X PUT repos/:owner/:repo/environments/$ENV 2>/dev/null || true

  # Set up specific environment
  case "$ENV" in
    "dev")
      setup_env "dev" "dev" "1" "3" "180" "10" "30"
      ;;
    "test")
      setup_env "test" "test" "2" "5" "240" "20" "45"
      ;;
    "prod")
      setup_env "prod" "prod" "3" "10" "300" "30" "60"
      ;;
  esac

  echo "$ENV environment configured successfully!"
fi

echo "\nReminder: Don't forget to set up secrets:"
echo "- AWS_ACCESS_KEY_ID"
echo "- AWS_SECRET_ACCESS_KEY"
echo "- SLACK_WEBHOOK_URL"
echo "\nYou can set them with:"
echo "gh secret set AWS_ACCESS_KEY_ID --body 'your-access-key'"
echo "gh secret set AWS_SECRET_ACCESS_KEY --body 'your-secret-key'"
echo "gh secret set SLACK_WEBHOOK_URL --body 'your-webhook-url'"
