#!/bin/bash
set -e

echo "🚀 Setting up GitHub Runner..."

# Update system and install basics
apt-get update
apt-get install -y curl wget unzip git jq

# Download and run full setup script
curl -o /tmp/runner-setup.sh https://raw.githubusercontent.com/${github_repo}/main/scripts/runner-setup.sh
chmod +x /tmp/runner-setup.sh

# Run setup with parameters
/tmp/runner-setup.sh "${github_token}" "${github_repo}" "${network_tier}"

echo "✅ GitHub runner setup completed!"