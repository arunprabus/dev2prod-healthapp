#!/bin/bash

# Comprehensive Infrastructure Job Summary Generator
# Usage: ./generate-job-summary.sh <environment> <action> <job_status>

ENVIRONMENT=${1:-dev}
ACTION=${2:-deploy}
JOB_STATUS=${3:-success}

echo "## 🏗️ Infrastructure Execution Report" >> $GITHUB_STEP_SUMMARY
echo "" >> $GITHUB_STEP_SUMMARY

# Basic execution details
echo "### 📋 Execution Details" >> $GITHUB_STEP_SUMMARY
echo "**Action:** $ACTION" >> $GITHUB_STEP_SUMMARY
echo "**Network Tier:** $ENVIRONMENT" >> $GITHUB_STEP_SUMMARY
echo "**Status:** $JOB_STATUS" >> $GITHUB_STEP_SUMMARY
echo "**Completed:** $(date '+%Y-%m-%d %H:%M:%S UTC')" >> $GITHUB_STEP_SUMMARY
echo "**Runner:** ${RUNNER_TYPE:-github}" >> $GITHUB_STEP_SUMMARY
echo "" >> $GITHUB_STEP_SUMMARY

# Current state and detailed infrastructure info
echo "### 📊 Infrastructure State & Network Design" >> $GITHUB_STEP_SUMMARY

# Get infrastructure details
K3S_IP=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=health-app-$ENVIRONMENT-k3s-node" "Name=instance-state-name,Values=running" --query "Reservations[0].Instances[0].PublicIpAddress" --output text 2>/dev/null || echo "N/A")
RUNNER_IP=$(aws ec2 describe-instances --filters "Name=tag:NetworkTier,Values=$ENVIRONMENT" "Name=tag:Name,Values=*runner*" "Name=instance-state-name,Values=running" --query "Reservations[0].Instances[0].PublicIpAddress" --output text 2>/dev/null || echo "N/A")
RDS_ENDPOINT=$(aws rds describe-db-instances --query "DBInstances[?contains(DBInstanceIdentifier, 'health-app-$ENVIRONMENT')].Endpoint.Address" --output text 2>/dev/null | cut -d'.' -f1 || echo "N/A")

echo "#### 🌐 Network Architecture" >> $GITHUB_STEP_SUMMARY
echo '```' >> $GITHUB_STEP_SUMMARY
echo "┌─────────────────────────────────────────────────────────────┐" >> $GITHUB_STEP_SUMMARY
echo "│                    AWS Region: ap-south-1                   │" >> $GITHUB_STEP_SUMMARY
echo "├─────────────────────────────────────────────────────────────┤" >> $GITHUB_STEP_SUMMARY

if [ "$ENVIRONMENT" = "lower" ]; then
  echo "│ ┌─────────────────────────────────────────────────────────┐ │" >> $GITHUB_STEP_SUMMARY
  echo "│ │                 LOWER NETWORK (ACTIVE)                 │ │" >> $GITHUB_STEP_SUMMARY
  echo "│ │ ┌─────────────┐  ┌─────────────┐  ┌─────────────────┐   │ │" >> $GITHUB_STEP_SUMMARY
  echo "│ │ │   K3S NODE  │  │ GITHUB RUN  │  │    DATABASE     │   │ │" >> $GITHUB_STEP_SUMMARY
  echo "│ │ │ $K3S_IP │  │ $RUNNER_IP │  │ $RDS_ENDPOINT   │   │ │" >> $GITHUB_STEP_SUMMARY
  echo "│ │ │   t2.micro  │  │   t2.micro  │  │   db.t3.micro   │   │ │" >> $GITHUB_STEP_SUMMARY
  echo "│ │ │  Port: 6443 │  │  SSH: 22    │  │   Port: 5432    │   │ │" >> $GITHUB_STEP_SUMMARY
  echo "│ │ └─────────────┘  └─────────────┘  └─────────────────┘   │ │" >> $GITHUB_STEP_SUMMARY
  echo "│ └─────────────────────────────────────────────────────────┘ │" >> $GITHUB_STEP_SUMMARY
elif [ "$ENVIRONMENT" = "higher" ]; then
  echo "│ ┌─────────────────────────────────────────────────────────┐ │" >> $GITHUB_STEP_SUMMARY
  echo "│ │                HIGHER NETWORK (ACTIVE)                 │ │" >> $GITHUB_STEP_SUMMARY
  echo "│ │ ┌─────────────┐                  ┌─────────────────────┐ │ │" >> $GITHUB_STEP_SUMMARY
  echo "│ │ │   K3S NODE  │                  │    DATABASE         │ │ │" >> $GITHUB_STEP_SUMMARY
  echo "│ │ │ $K3S_IP │                  │ $RDS_ENDPOINT       │ │ │" >> $GITHUB_STEP_SUMMARY
  echo "│ │ │   t2.micro  │                  │   db.t3.micro       │ │ │" >> $GITHUB_STEP_SUMMARY
  echo "│ │ │  Port: 6443 │                  │   Port: 5432        │ │ │" >> $GITHUB_STEP_SUMMARY
  echo "│ │ └─────────────┘                  └─────────────────────┘ │ │" >> $GITHUB_STEP_SUMMARY
  echo "│ │                                                         │ │" >> $GITHUB_STEP_SUMMARY
  echo "│ │ ┌─────────────┐                                        │ │" >> $GITHUB_STEP_SUMMARY
  echo "│ │ │ GITHUB RUN  │                                        │ │" >> $GITHUB_STEP_SUMMARY
  echo "│ │ │ $RUNNER_IP │                                        │ │" >> $GITHUB_STEP_SUMMARY
  echo "│ │ │   t2.micro  │                                        │ │" >> $GITHUB_STEP_SUMMARY
  echo "│ │ └─────────────┘                                        │ │" >> $GITHUB_STEP_SUMMARY
  echo "│ └─────────────────────────────────────────────────────────┘ │" >> $GITHUB_STEP_SUMMARY
elif [ "$ENVIRONMENT" = "monitoring" ]; then
  echo "│ ┌─────────────────────────────────────────────────────────┐ │" >> $GITHUB_STEP_SUMMARY
  echo "│ │              MONITORING NETWORK (ACTIVE)               │ │" >> $GITHUB_STEP_SUMMARY
  echo "│ │ ┌─────────────────────────────────────────────────────┐ │ │" >> $GITHUB_STEP_SUMMARY
  echo "│ │ │              MONITORING CLUSTER                     │ │ │" >> $GITHUB_STEP_SUMMARY
  echo "│ │ │         K3s Master + GitHub Runner                  │ │ │" >> $GITHUB_STEP_SUMMARY
  echo "│ │ │         $K3S_IP + $RUNNER_IP                        │ │ │" >> $GITHUB_STEP_SUMMARY
  echo "│ │ │         Prometheus + Grafana                        │ │ │" >> $GITHUB_STEP_SUMMARY
  echo "│ │ │                t2.micro                             │ │ │" >> $GITHUB_STEP_SUMMARY
  echo "│ │ └─────────────────────────────────────────────────────┘ │ │" >> $GITHUB_STEP_SUMMARY
  echo "│ └─────────────────────────────────────────────────────────┘ │" >> $GITHUB_STEP_SUMMARY
fi

echo "└─────────────────────────────────────────────────────────────┘" >> $GITHUB_STEP_SUMMARY
echo '```' >> $GITHUB_STEP_SUMMARY
echo "" >> $GITHUB_STEP_SUMMARY

echo "#### 💻 Resource Details" >> $GITHUB_STEP_SUMMARY
echo '```' >> $GITHUB_STEP_SUMMARY
aws ec2 describe-instances --filters "Name=tag:NetworkTier,Values=$ENVIRONMENT" "Name=instance-state-name,Values=running" --query "Reservations[*].Instances[*].[Tags[?Key=='Name'].Value|[0],InstanceType,PublicIpAddress,PrivateIpAddress,State.Name]" --output table >> $GITHUB_STEP_SUMMARY 2>/dev/null || echo "No EC2 instances found" >> $GITHUB_STEP_SUMMARY
echo '```' >> $GITHUB_STEP_SUMMARY
echo "" >> $GITHUB_STEP_SUMMARY

# Connection details if resources exist
if [ "$K3S_IP" != "None" ] && [ "$K3S_IP" != "N/A" ]; then
  echo "#### 🚀 Access Information" >> $GITHUB_STEP_SUMMARY
  
  echo "**K3s Cluster:** \`ssh -i ~/.ssh/key ubuntu@$K3S_IP\`" >> $GITHUB_STEP_SUMMARY
  echo "**K3s API:** https://$K3S_IP:6443" >> $GITHUB_STEP_SUMMARY
  
  if [ "$RUNNER_IP" != "None" ] && [ "$RUNNER_IP" != "N/A" ]; then
    echo "**GitHub Runner:** \`ssh -i ~/.ssh/key ubuntu@$RUNNER_IP\`" >> $GITHUB_STEP_SUMMARY
    echo "**Runner Labels:** self-hosted, github-runner-$ENVIRONMENT" >> $GITHUB_STEP_SUMMARY
  fi
  
  if [ "$RDS_ENDPOINT" != "None" ] && [ "$RDS_ENDPOINT" != "N/A" ]; then
    echo "**Database:** $RDS_ENDPOINT:5432" >> $GITHUB_STEP_SUMMARY
  fi
  
  # DNS Setup Instructions
  echo "" >> $GITHUB_STEP_SUMMARY
  echo "#### 🌐 DNS Setup Required (sharpzeal.com)" >> $GITHUB_STEP_SUMMARY
  echo "" >> $GITHUB_STEP_SUMMARY
  
  if [ "$ENVIRONMENT" = "lower" ]; then
    echo "**📋 Add these A records in Namecheap:**" >> $GITHUB_STEP_SUMMARY
    echo "" >> $GITHUB_STEP_SUMMARY
    echo "| Host | Value | TTL |" >> $GITHUB_STEP_SUMMARY
    echo "|------|-------|-----|" >> $GITHUB_STEP_SUMMARY
    echo "| \`dev\` | \`$K3S_IP\` | 300 |" >> $GITHUB_STEP_SUMMARY
    echo "| \`test\` | \`$K3S_IP\` | 300 |" >> $GITHUB_STEP_SUMMARY
    echo "" >> $GITHUB_STEP_SUMMARY
    echo "**🎯 Result URLs:**" >> $GITHUB_STEP_SUMMARY
    echo "- Development: https://dev.sharpzeal.com" >> $GITHUB_STEP_SUMMARY
    echo "- Test: https://test.sharpzeal.com" >> $GITHUB_STEP_SUMMARY
  elif [ "$ENVIRONMENT" = "higher" ]; then
    echo "**📋 Add this A record in Namecheap:**" >> $GITHUB_STEP_SUMMARY
    echo "" >> $GITHUB_STEP_SUMMARY
    echo "| Host | Value | TTL |" >> $GITHUB_STEP_SUMMARY
    echo "|------|-------|-----|" >> $GITHUB_STEP_SUMMARY
    echo "| \`health-api\` | \`$K3S_IP\` | 300 |" >> $GITHUB_STEP_SUMMARY
    echo "" >> $GITHUB_STEP_SUMMARY
    echo "**🎯 Result URL:**" >> $GITHUB_STEP_SUMMARY
    echo "- Production: https://health-api.sharpzeal.com" >> $GITHUB_STEP_SUMMARY
  elif [ "$ENVIRONMENT" = "monitoring" ]; then
    echo "**📋 Monitoring cluster deployed:**" >> $GITHUB_STEP_SUMMARY
    echo "- IP: $K3S_IP" >> $GITHUB_STEP_SUMMARY
    echo "- Used for centralized monitoring and GitHub runners" >> $GITHUB_STEP_SUMMARY
  fi
  
  echo "" >> $GITHUB_STEP_SUMMARY
  echo "#### 🔧 Next Steps" >> $GITHUB_STEP_SUMMARY
  echo "1. **Setup DNS** - Add A records in Namecheap (see table above)" >> $GITHUB_STEP_SUMMARY
  echo "2. **Setup Ingress** - SSH to cluster and run: \`./scripts/setup-ingress.sh $ENVIRONMENT\`" >> $GITHUB_STEP_SUMMARY
  echo "3. **Deploy Apps** - Run Core Deployment workflow" >> $GITHUB_STEP_SUMMARY
  echo "4. **Verify SSL** - Check https URLs after DNS propagation (5-10 min)" >> $GITHUB_STEP_SUMMARY
else
  echo "**Status:** No infrastructure deployed" >> $GITHUB_STEP_SUMMARY
fi