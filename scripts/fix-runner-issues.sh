#!/bin/bash
# GitHub Runner Issue Fixer
# Usage: ./fix-runner-issues.sh [network_tier]

set -e

NETWORK_TIER=${1:-lower}
AWS_REGION=${AWS_REGION:-ap-south-1}

echo "🔧 Fixing GitHub Runner Issues for network tier: $NETWORK_TIER"
echo "============================================================="

# Get runner instance details
echo "📍 Finding runner instance..."
RUNNER_INSTANCE_ID=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=health-app-runner-$NETWORK_TIER" "Name=instance-state-name,Values=running" \
  --query 'Reservations[0].Instances[0].InstanceId' \
  --output text 2>/dev/null)

if [ "$RUNNER_INSTANCE_ID" == "None" ] || [ -z "$RUNNER_INSTANCE_ID" ]; then
  echo "❌ Runner instance not found for network tier: $NETWORK_TIER"
  exit 1
fi

echo "✅ Runner instance found: $RUNNER_INSTANCE_ID"

# Check SSM connectivity
echo ""
echo "🔗 Checking SSM connectivity..."
SSM_STATUS=$(aws ssm describe-instance-information --filters "Key=InstanceIds,Values=$RUNNER_INSTANCE_ID" --query 'InstanceInformationList[0].PingStatus' --output text 2>/dev/null || echo "unknown")

if [ "$SSM_STATUS" != "Online" ]; then
  echo "❌ SSM Agent is not online. Cannot perform remote fixes."
  echo "💡 Try connecting via SSH and run fixes manually"
  exit 1
fi

echo "✅ SSM Agent is online"

# Function to run command via SSM
run_ssm_command() {
  local command="$1"
  local description="$2"
  
  echo "🔧 $description..."
  
  COMMAND_ID=$(aws ssm send-command \
    --instance-ids $RUNNER_INSTANCE_ID \
    --document-name "AWS-RunShellScript" \
    --parameters "commands=[\"$command\"]" \
    --query 'Command.CommandId' --output text 2>/dev/null)
  
  if [ -n "$COMMAND_ID" ] && [ "$COMMAND_ID" != "None" ]; then
    sleep 10
    RESULT=$(aws ssm get-command-invocation \
      --command-id $COMMAND_ID \
      --instance-id $RUNNER_INSTANCE_ID \
      --query 'StandardOutputContent' --output text 2>/dev/null || echo "Command failed")
    
    echo "📋 Result:"
    echo "$RESULT"
    echo ""
  else
    echo "❌ Failed to execute command"
    echo ""
  fi
}

# Fix 1: Check and restart runner service
run_ssm_command "
echo '=== Current Runner Status ==='
systemctl status actions.runner.* --no-pager 2>/dev/null || echo 'No runner service found'
ps aux | grep -E '(Runner|run.sh)' | grep -v grep || echo 'No runner process found'

echo '=== Stopping existing processes ==='
sudo systemctl stop actions.runner.* 2>/dev/null || echo 'No service to stop'
sudo pkill -f Runner.Listener || echo 'No Runner.Listener to kill'
sudo pkill -f RunnerService.js || echo 'No RunnerService.js to kill'
sleep 5

echo '=== Starting runner service ==='
sudo systemctl start actions.runner.* 2>/dev/null || echo 'Service start failed'
sleep 10

echo '=== New Status ==='
systemctl status actions.runner.* --no-pager 2>/dev/null || echo 'Service still not found'
ps aux | grep -E '(Runner|run.sh)' | grep -v grep || echo 'Process still not found'
" "Restarting runner service"

# Fix 2: Check runner directory and permissions
run_ssm_command "
echo '=== Checking runner directory ==='
ls -la /home/ubuntu/actions-runner/ 2>/dev/null || echo 'Runner directory not found'

echo '=== Checking ownership ==='
ls -la /home/ubuntu/ | grep actions-runner || echo 'No actions-runner directory'

echo '=== Fixing ownership ==='
sudo chown -R ubuntu:ubuntu /home/ubuntu/actions-runner/ 2>/dev/null || echo 'Could not fix ownership'

echo '=== Checking runner files ==='
ls -la /home/ubuntu/actions-runner/run.sh 2>/dev/null || echo 'run.sh not found'
ls -la /home/ubuntu/actions-runner/config.sh 2>/dev/null || echo 'config.sh not found'
ls -la /home/ubuntu/actions-runner/svc.sh 2>/dev/null || echo 'svc.sh not found'
" "Checking runner directory and permissions"

# Fix 3: Re-register runner if needed
if [ -n "$GITHUB_TOKEN" ] || [ -n "$REPO_PAT" ]; then
  TOKEN=${GITHUB_TOKEN:-$REPO_PAT}
  REPO=${GITHUB_REPOSITORY:-"arunprabus/dev2prod-healthapp"}
  
  echo "🔧 Re-registering runner with GitHub..."
  
  # Get registration token
  REG_TOKEN=$(curl -s -X POST -H "Authorization: token $TOKEN" \
    -H "Accept: application/vnd.github.v3+json" \
    "https://api.github.com/repos/$REPO/actions/runners/registration-token" | \
    jq -r '.token' 2>/dev/null)
  
  if [ -n "$REG_TOKEN" ] && [ "$REG_TOKEN" != "null" ]; then
    echo "✅ Got registration token"
    
    run_ssm_command "
echo '=== Re-configuring runner ==='
cd /home/ubuntu/actions-runner
sudo -u ubuntu ./config.sh remove --token $REG_TOKEN 2>/dev/null || echo 'Remove failed or not needed'
sleep 5

RUNNER_NAME=\"github-runner-$NETWORK_TIER-\$(hostname | cut -d'-' -f3-)\"
LABELS=\"github-runner-$NETWORK_TIER\"

echo \"Configuring runner: \$RUNNER_NAME\"
sudo -u ubuntu ./config.sh --url https://github.com/$REPO --token $REG_TOKEN --name \"\$RUNNER_NAME\" --labels \"\$LABELS\" --unattended --replace

echo '=== Installing service ==='
sudo ./svc.sh install ubuntu
sudo ./svc.sh start

echo '=== Final status ==='
systemctl status actions.runner.* --no-pager 2>/dev/null || echo 'Service status unknown'
" "Re-registering runner"
  else
    echo "❌ Could not get registration token"
  fi
else
  echo "⚠️ No GitHub token provided - skipping re-registration"
fi

# Fix 4: Check network connectivity
run_ssm_command "
echo '=== Network Connectivity Test ==='
ping -c 3 8.8.8.8 || echo 'Internet connectivity failed'
curl -s --connect-timeout 10 https://api.github.com/rate_limit > /dev/null && echo 'GitHub API accessible' || echo 'GitHub API not accessible'
curl -s --connect-timeout 10 https://github.com > /dev/null && echo 'GitHub.com accessible' || echo 'GitHub.com not accessible'

echo '=== DNS Resolution ==='
nslookup github.com || echo 'DNS resolution failed'
" "Testing network connectivity"

# Fix 5: Check logs and create debug info
run_ssm_command "
echo '=== Recent Cloud-init Log ==='
tail -20 /var/log/cloud-init-output.log 2>/dev/null || echo 'No cloud-init log'

echo '=== Runner Config Log ==='
cat /var/log/runner-config.log 2>/dev/null || echo 'No runner config log'

echo '=== Service Logs ==='
journalctl -u actions.runner.* --no-pager -n 10 2>/dev/null || echo 'No service logs'

echo '=== Health Monitor Log ==='
tail -10 /var/log/runner-logs/health-monitor.log 2>/dev/null || echo 'No health monitor log'

echo '=== Disk Space ==='
df -h

echo '=== Memory Usage ==='
free -h
" "Collecting debug information"

# Final status check
echo "🔍 Final status check..."
run_ssm_command "
echo '=== Final Runner Status ==='
systemctl is-active actions.runner.* 2>/dev/null && echo 'Service is active' || echo 'Service is not active'
ps aux | grep -E '(Runner|run.sh)' | grep -v grep && echo 'Runner process found' || echo 'No runner process'

echo '=== GitHub Connectivity ==='
curl -s --connect-timeout 10 https://api.github.com/rate_limit > /dev/null && echo 'GitHub API OK' || echo 'GitHub API failed'
" "Final status check"

echo ""
echo "🎉 Runner fix attempts completed!"
echo ""
echo "📋 Next steps:"
echo "1. Check GitHub Settings > Actions > Runners for your repository"
echo "2. Look for runner named: github-runner-$NETWORK_TIER-*"
echo "3. If still not working, try manual SSH connection:"
echo "   aws ssm start-session --target $RUNNER_INSTANCE_ID"
echo "4. On the instance, run: /home/ubuntu/debug-runner.sh"
echo "5. Or restart manually: /home/ubuntu/restart-runner.sh"