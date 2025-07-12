#!/bin/bash
exec > /var/log/user-data.log 2>&1
set -e

echo "=== ALTERNATIVE USER DATA STARTED ==="
date

# Update system
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y curl wget git jq

# Create runner user and directory
useradd -m -s /bin/bash runner || true
mkdir -p /home/runner/actions-runner
cd /home/runner/actions-runner

# Download runner
echo "Downloading GitHub Actions runner..."
RUNNER_VERSION="2.311.0"
curl -o actions-runner-linux-x64-$RUNNER_VERSION.tar.gz -L https://github.com/actions/runner/releases/download/v$RUNNER_VERSION/actions-runner-linux-x64-$RUNNER_VERSION.tar.gz
tar xzf ./actions-runner-linux-x64-$RUNNER_VERSION.tar.gz
chown -R runner:runner /home/runner/actions-runner

# Install dependencies
./bin/installdependencies.sh

# Alternative: Use GitHub CLI for registration
echo "Installing GitHub CLI..."
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null
apt update
apt install -y gh

# Configure runner with retry logic
RUNNER_NAME="github-runner-${network_tier}-$(date +%s)"
LABELS="github-runner-${network_tier}"

echo "Configuring runner: $RUNNER_NAME with labels: $LABELS"

# Method 1: Direct API call with better error handling
for attempt in {1..5}; do
    echo "Registration attempt $attempt..."
    
    # Get registration token
    REG_TOKEN=$(curl -s -X POST \
        -H "Authorization: token ${github_token}" \
        -H "Accept: application/vnd.github.v3+json" \
        -H "User-Agent: GitHub-Runner-Setup" \
        https://api.github.com/repos/${github_repo}/actions/runners/registration-token | jq -r '.token')
    
    if [[ "$REG_TOKEN" != "null" && "$REG_TOKEN" != "" ]]; then
        echo "Got registration token, configuring runner..."
        
        # Configure as runner user
        sudo -u runner bash -c "cd /home/runner/actions-runner && ./config.sh --url https://github.com/${github_repo} --token '$REG_TOKEN' --name '$RUNNER_NAME' --labels '$LABELS' --unattended --replace" && break
        
        echo "Configuration successful!"
        break
    else
        echo "Failed to get token, waiting before retry..."
        sleep $((attempt * 10))
    fi
done

# Install and start service
echo "Installing runner service..."
./svc.sh install runner
./svc.sh start

# Wait and verify
sleep 15
if systemctl is-active --quiet actions.runner.*.service; then
    echo "✅ Runner service is running successfully"
    systemctl status actions.runner.*.service --no-pager
else
    echo "❌ Runner service failed to start"
    systemctl status actions.runner.*.service --no-pager || true
    journalctl -u actions.runner.*.service --no-pager -n 50 || true
fi

echo "SUCCESS" > /var/log/user-data-complete
echo "=== USER DATA COMPLETED ==="
date