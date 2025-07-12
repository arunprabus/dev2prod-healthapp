#!/bin/bash

# Manual GitHub Runner Setup Script
# Usage: ./manual-runner-setup.sh <network_tier> <github_token> <repo_name>

NETWORK_TIER=${1:-lower}
GITHUB_TOKEN=${2}
REPO_NAME=${3:-"your-username/dev2prod-healthapp"}

if [[ -z "$GITHUB_TOKEN" ]]; then
    echo "Usage: $0 <network_tier> <github_token> <repo_name>"
    echo "Example: $0 lower ghp_xxxx your-username/dev2prod-healthapp"
    exit 1
fi

echo "=== Manual GitHub Runner Setup ==="
echo "Network Tier: $NETWORK_TIER"
echo "Repository: $REPO_NAME"

# Get runner instance IP
RUNNER_IP=$(aws ec2 describe-instances \
    --filters "Name=tag:NetworkTier,Values=$NETWORK_TIER" "Name=tag:Type,Values=github-runner" "Name=instance-state-name,Values=running" \
    --query "Reservations[0].Instances[0].PublicIpAddress" \
    --output text)

if [[ "$RUNNER_IP" == "None" || "$RUNNER_IP" == "" ]]; then
    echo "ERROR: No running GitHub runner found for network tier: $NETWORK_TIER"
    exit 1
fi

echo "Runner IP: $RUNNER_IP"

# Create setup script
cat > /tmp/setup-runner.sh << 'EOF'
#!/bin/bash
set -e

GITHUB_TOKEN="$1"
REPO_NAME="$2"
NETWORK_TIER="$3"

echo "Setting up GitHub runner..."

# Stop existing service if running
sudo systemctl stop actions.runner.*.service 2>/dev/null || true

# Clean up existing runner
sudo rm -rf /home/ubuntu/actions-runner
mkdir -p /home/ubuntu/actions-runner
cd /home/ubuntu/actions-runner

# Download runner
curl -o actions-runner-linux-x64-2.311.0.tar.gz -L https://github.com/actions/runner/releases/download/v2.311.0/actions-runner-linux-x64-2.311.0.tar.gz
tar xzf ./actions-runner-linux-x64-2.311.0.tar.gz

# Install dependencies
sudo ./bin/installdependencies.sh

# Get registration token
echo "Getting registration token..."
REG_TOKEN=$(curl -s -X POST \
    -H "Authorization: token $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github.v3+json" \
    https://api.github.com/repos/$REPO_NAME/actions/runners/registration-token | jq -r '.token')

if [[ "$REG_TOKEN" == "null" || "$REG_TOKEN" == "" ]]; then
    echo "ERROR: Failed to get registration token"
    exit 1
fi

# Configure runner
RUNNER_NAME="github-runner-$NETWORK_TIER-$(date +%s)"
LABELS="github-runner-$NETWORK_TIER"

echo "Configuring runner: $RUNNER_NAME"
./config.sh --url https://github.com/$REPO_NAME --token "$REG_TOKEN" --name "$RUNNER_NAME" --labels "$LABELS" --unattended --replace

# Install and start service
sudo ./svc.sh install ubuntu
sudo ./svc.sh start

echo "Runner setup complete!"
systemctl status actions.runner.*.service
EOF

# Copy and execute setup script
echo "Copying setup script to runner..."
scp -i ~/.ssh/k3s-key -o StrictHostKeyChecking=no /tmp/setup-runner.sh ubuntu@$RUNNER_IP:/tmp/

echo "Executing setup script..."
ssh -i ~/.ssh/k3s-key -o StrictHostKeyChecking=no ubuntu@$RUNNER_IP "chmod +x /tmp/setup-runner.sh && /tmp/setup-runner.sh '$GITHUB_TOKEN' '$REPO_NAME' '$NETWORK_TIER'"

echo "✅ Manual runner setup completed!"
echo "Check GitHub repository Settings > Actions > Runners to verify"