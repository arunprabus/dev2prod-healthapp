#!/bin/bash
# Refresh GitHub Runner Token
# Usage: ./refresh-runner-token.sh <github_pat> <repo_name> <runner_name>

set -e

GITHUB_PAT="$1"
REPO_NAME="$2"
RUNNER_NAME="$3"

if [[ -z "$GITHUB_PAT" || -z "$REPO_NAME" || -z "$RUNNER_NAME" ]]; then
    echo "Usage: $0 <github_pat> <repo_name> <runner_name>"
    exit 1
fi

echo "🔄 Refreshing runner token for $RUNNER_NAME"

# Get new registration token
REG_TOKEN=$(curl -s -X POST \
    -H "Authorization: token $GITHUB_PAT" \
    -H "Accept: application/vnd.github.v3+json" \
    https://api.github.com/repos/$REPO_NAME/actions/runners/registration-token | \
    jq -r '.token')

if [[ "$REG_TOKEN" == "null" || -z "$REG_TOKEN" ]]; then
    echo "❌ Failed to get registration token"
    exit 1
fi

echo "✅ New token obtained"

# Stop current runner
sudo systemctl stop actions.runner.*

# Remove old configuration
cd /home/ubuntu/actions-runner
sudo -u ubuntu ./config.sh remove --token "$REG_TOKEN"

# Re-configure with new token
sudo -u ubuntu ./config.sh \
    --url "https://github.com/$REPO_NAME" \
    --token "$REG_TOKEN" \
    --name "$RUNNER_NAME" \
    --labels "awsrunnerlocal,aws-lower,aws-dev,aws-test,self-hosted,terraform,kubectl,docker" \
    --unattended

# Restart service
sudo systemctl start actions.runner.*

echo "✅ Runner token refreshed successfully"