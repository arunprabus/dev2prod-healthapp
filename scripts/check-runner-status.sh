#!/bin/bash
# GitHub Runner Status Checker
# Usage: ./check-runner-status.sh [network_tier]

set -e

NETWORK_TIER=${1:-lower}
AWS_REGION=${AWS_REGION:-ap-south-1}

echo "🔍 Checking GitHub Runner Status for network tier: $NETWORK_TIER"
echo "=================================================="

# Get runner instance details
echo "📍 Finding runner instance..."
RUNNER_INSTANCE_ID=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=health-app-runner-$NETWORK_TIER" "Name=instance-state-name,Values=running" \
  --query 'Reservations[0].Instances[0].InstanceId' \
  --output text 2>/dev/null)

RUNNER_PUBLIC_IP=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=health-app-runner-$NETWORK_TIER" "Name=instance-state-name,Values=running" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text 2>/dev/null)

RUNNER_PRIVATE_IP=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=health-app-runner-$NETWORK_TIER" "Name=instance-state-name,Values=running" \
  --query 'Reservations[0].Instances[0].PrivateIpAddress' \
  --output text 2>/dev/null)

if [ "$RUNNER_INSTANCE_ID" == "None" ] || [ -z "$RUNNER_INSTANCE_ID" ]; then
  echo "❌ Runner instance not found for network tier: $NETWORK_TIER"
  echo "🔍 Available runner instances:"
  aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=health-app-runner-*" \
    --query 'Reservations[].Instances[].[InstanceId,State.Name,Tags[?Key==`Name`].Value|[0],PublicIpAddress]' \
    --output table
  exit 1
fi

echo "✅ Runner instance found:"
echo "   Instance ID: $RUNNER_INSTANCE_ID"
echo "   Public IP: $RUNNER_PUBLIC_IP"
echo "   Private IP: $RUNNER_PRIVATE_IP"

# Check instance status
echo ""
echo "🏥 Instance Health Check..."
INSTANCE_STATUS=$(aws ec2 describe-instance-status --instance-ids $RUNNER_INSTANCE_ID --query 'InstanceStatuses[0].InstanceStatus.Status' --output text 2>/dev/null || echo "unknown")
SYSTEM_STATUS=$(aws ec2 describe-instance-status --instance-ids $RUNNER_INSTANCE_ID --query 'InstanceStatuses[0].SystemStatus.Status' --output text 2>/dev/null || echo "unknown")

echo "   Instance Status: $INSTANCE_STATUS"
echo "   System Status: $SYSTEM_STATUS"

# Check SSM connectivity
echo ""
echo "🔗 SSM Connectivity Check..."
SSM_STATUS=$(aws ssm describe-instance-information --filters "Key=InstanceIds,Values=$RUNNER_INSTANCE_ID" --query 'InstanceInformationList[0].PingStatus' --output text 2>/dev/null || echo "unknown")
echo "   SSM Agent Status: $SSM_STATUS"

if [ "$SSM_STATUS" == "Online" ]; then
  echo "✅ SSM Agent is online - can use Session Manager"
  
  # Get detailed status via SSM
  echo ""
  echo "🔍 Getting detailed status from instance..."
  
  STATUS_COMMAND=$(aws ssm send-command \
    --instance-ids $RUNNER_INSTANCE_ID \
    --document-name "AWS-RunShellScript" \
    --parameters 'commands=["echo === System Info ===; uptime; echo === Cloud-init Status ===; cloud-init status --long 2>/dev/null || echo cloud-init not available; echo === Runner Service Status ===; systemctl status actions.runner.* --no-pager 2>/dev/null || echo No runner service found; echo === Runner Process ===; ps aux | grep -E \"(Runner|run.sh)\" | grep -v grep || echo No runner process found; echo === GitHub Actions Directory ===; ls -la /home/ubuntu/actions-runner/ 2>/dev/null || echo Directory not found; echo === Recent Logs ===; tail -10 /var/log/cloud-init-output.log 2>/dev/null || echo No cloud-init log"]' \
    --query 'Command.CommandId' --output text 2>/dev/null)
  
  if [ -n "$STATUS_COMMAND" ] && [ "$STATUS_COMMAND" != "None" ]; then
    echo "⏳ Waiting for command execution..."
    sleep 10
    
    echo "📋 Instance Status Report:"
    echo "=========================="
    aws ssm get-command-invocation \
      --command-id $STATUS_COMMAND \
      --instance-id $RUNNER_INSTANCE_ID \
      --query 'StandardOutputContent' --output text 2>/dev/null || echo "Could not retrieve status"
  fi
  
  # Check runner logs
  echo ""
  echo "📝 Getting runner logs..."
  LOG_COMMAND=$(aws ssm send-command \
    --instance-ids $RUNNER_INSTANCE_ID \
    --document-name "AWS-RunShellScript" \
    --parameters 'commands=["echo === Runner Config Log ===; cat /var/log/runner-config.log 2>/dev/null || echo No config log; echo === Runner Health Monitor ===; tail -20 /var/log/runner-logs/health-monitor.log 2>/dev/null || echo No health monitor log; echo === Service Logs ===; journalctl -u actions.runner.* --no-pager -n 10 2>/dev/null || echo No service logs"]' \
    --query 'Command.CommandId' --output text 2>/dev/null)
  
  if [ -n "$LOG_COMMAND" ] && [ "$LOG_COMMAND" != "None" ]; then
    sleep 10
    echo "📋 Runner Logs:"
    echo "==============="
    aws ssm get-command-invocation \
      --command-id $LOG_COMMAND \
      --instance-id $RUNNER_INSTANCE_ID \
      --query 'StandardOutputContent' --output text 2>/dev/null || echo "Could not retrieve logs"
  fi
  
else
  echo "❌ SSM Agent is not online - cannot get detailed status"
  echo "💡 Try connecting via SSH: ssh -i your-key.pem ubuntu@$RUNNER_PUBLIC_IP"
fi

# Check GitHub API for registered runners
echo ""
echo "🐙 GitHub API Runner Check..."
if [ -n "$GITHUB_TOKEN" ] || [ -n "$REPO_PAT" ]; then
  TOKEN=${GITHUB_TOKEN:-$REPO_PAT}
  REPO=${GITHUB_REPOSITORY:-"arunprabus/dev2prod-healthapp"}
  
  echo "   Repository: $REPO"
  
  GITHUB_RUNNERS=$(curl -s -H "Authorization: token $TOKEN" \
    -H "Accept: application/vnd.github.v3+json" \
    "https://api.github.com/repos/$REPO/actions/runners" 2>/dev/null | \
    jq -r '.runners[] | select(.name | contains("github-runner-'$NETWORK_TIER'")) | "   \(.name) - \(.status) - \(.busy)"' 2>/dev/null)
  
  if [ -n "$GITHUB_RUNNERS" ]; then
    echo "✅ Found registered runners:"
    echo "$GITHUB_RUNNERS"
  else
    echo "❌ No runners found for network tier: $NETWORK_TIER"
    echo "🔍 All registered runners:"
    curl -s -H "Authorization: token $TOKEN" \
      -H "Accept: application/vnd.github.v3+json" \
      "https://api.github.com/repos/$REPO/actions/runners" 2>/dev/null | \
      jq -r '.runners[] | "   \(.name) - \(.status) - \(.busy)"' 2>/dev/null || echo "   Could not retrieve runners"
  fi
else
  echo "⚠️ No GitHub token provided (set GITHUB_TOKEN or REPO_PAT)"
  echo "💡 Cannot check GitHub API for runner registration"
fi

# Provide troubleshooting commands
echo ""
echo "🛠️ Troubleshooting Commands:"
echo "============================"
echo "Connect via Session Manager:"
echo "   aws ssm start-session --target $RUNNER_INSTANCE_ID"
echo ""
echo "Connect via SSH (if you have the key):"
echo "   ssh -i your-key.pem ubuntu@$RUNNER_PUBLIC_IP"
echo ""
echo "Check runner status on instance:"
echo "   sudo systemctl status actions.runner.*"
echo "   ps aux | grep Runner"
echo "   /home/ubuntu/debug-runner.sh"
echo ""
echo "Restart runner on instance:"
echo "   /home/ubuntu/restart-runner.sh"
echo "   sudo systemctl restart actions.runner.*"
echo ""
echo "View logs on instance:"
echo "   tail -f /var/log/cloud-init-output.log"
echo "   tail -f /var/log/runner-config.log"
echo "   tail -f /var/log/runner-logs/health-monitor.log"

echo ""
echo "✅ Runner status check completed!"