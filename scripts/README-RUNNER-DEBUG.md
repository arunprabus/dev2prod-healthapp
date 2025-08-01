# GitHub Runner Debugging Scripts

## Overview

These scripts help debug and fix GitHub Actions self-hosted runner issues in the health app infrastructure.

## Scripts

### 1. `check-runner-status.sh`

**Purpose**: Check the status of GitHub Actions runner
**Usage**: `./check-runner-status.sh [network_tier]`

**What it does**:
- Finds the runner EC2 instance
- Checks instance health and SSM connectivity
- Gets detailed status from the instance
- Checks GitHub API for runner registration
- Provides troubleshooting commands

**Example**:
```bash
# Check lower tier runner
./check-runner-status.sh lower

# Check higher tier runner  
./check-runner-status.sh higher
```

### 2. `fix-runner-issues.sh`

**Purpose**: Automatically fix common runner issues
**Usage**: `./fix-runner-issues.sh [network_tier]`

**What it fixes**:
- Restarts runner service
- Fixes file permissions
- Re-registers runner with GitHub
- Tests network connectivity
- Collects debug information

**Example**:
```bash
# Fix lower tier runner issues
./fix-runner-issues.sh lower
```

## Prerequisites

1. **AWS CLI configured** with appropriate credentials
2. **Environment variables** (optional but recommended):
   ```bash
   export AWS_REGION=ap-south-1
   export GITHUB_TOKEN=your_github_token
   export GITHUB_REPOSITORY=arunprabus/dev2prod-healthapp
   ```

## Common Issues and Solutions

### Issue: Runner not showing in GitHub

**Symptoms**:
- Runner instance is running
- No runner appears in GitHub Settings > Actions > Runners

**Solution**:
```bash
./fix-runner-issues.sh lower
```

### Issue: Runner shows as offline

**Symptoms**:
- Runner appears in GitHub but shows as offline
- Jobs queue but don't start

**Solution**:
1. Check status: `./check-runner-status.sh lower`
2. If service is down: `./fix-runner-issues.sh lower`

### Issue: Cannot connect to runner instance

**Symptoms**:
- SSM Agent shows as offline
- Cannot execute remote commands

**Solution**:
1. Check instance status in AWS Console
2. Restart instance if needed
3. Wait for SSM Agent to come online

## Manual Debugging

If scripts don't work, connect manually:

### Via Session Manager:
```bash
aws ssm start-session --target i-1234567890abcdef0
```

### Via SSH (if you have the key):
```bash
ssh -i your-key.pem ubuntu@RUNNER_PUBLIC_IP
```

### On the instance, run:
```bash
# Check runner status
/home/ubuntu/debug-runner.sh

# Check GitHub connectivity
/home/ubuntu/check-runner-github.sh

# Restart runner
/home/ubuntu/restart-runner.sh

# View logs
tail -f /var/log/cloud-init-output.log
tail -f /var/log/runner-config.log
tail -f /var/log/runner-logs/health-monitor.log
```

## Workflow Integration

The enhanced infrastructure workflow now includes:

1. **Detailed logging** during runner setup
2. **Status monitoring** with real-time updates
3. **Automatic helper script creation** on the instance
4. **GitHub API checks** for runner registration

## Troubleshooting Workflow

1. **Check workflow logs** in GitHub Actions
2. **Run status check**: `./check-runner-status.sh lower`
3. **Try automatic fix**: `./fix-runner-issues.sh lower`
4. **Manual connection** if needed
5. **Check GitHub Settings** > Actions > Runners

## Log Locations

**On the runner instance**:
- `/var/log/cloud-init-output.log` - Instance initialization
- `/var/log/runner-config.log` - Runner configuration
- `/var/log/runner-logs/health-monitor.log` - Health monitoring
- `/home/ubuntu/actions-runner/_diag/` - Runner diagnostic logs

**In S3** (if configured):
- `s3://bucket/runner-logs/NETWORK_TIER/INSTANCE_ID/`

## Network Tiers

- **lower**: Development and test environments
- **higher**: Production environment  
- **monitoring**: Monitoring infrastructure

Each tier has its own runner instance with appropriate labels.