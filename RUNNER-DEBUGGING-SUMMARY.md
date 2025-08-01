# GitHub Runner Debugging Enhancements

## What We Added

### 1. Enhanced Workflow Logging

**File**: `.github/workflows/core-infrastructure.yml`

**Improvements**:
- ✅ **Real-time monitoring** of instance initialization
- ✅ **SSM connectivity checks** with status updates
- ✅ **Cloud-init progress tracking** via remote commands
- ✅ **Runner service status monitoring** during setup
- ✅ **GitHub API integration** to check runner registration
- ✅ **Detailed log collection** from the instance
- ✅ **Helper script creation** on the runner instance

**What you'll see in GitHub Actions console**:
```
🏃 Step 3: Setting up GitHub self-hosted runner with detailed monitoring...
🔍 Finding runner instance...
✅ Runner instance found:
   Instance ID: i-1234567890abcdef0
   Public IP: 13.232.xxx.xxx
📊 Monitoring instance initialization...
   Check 1/20: Instance=ok, System=ok
✅ Instance fully initialized
📋 Monitoring cloud-init and runner setup...
   Setup check 1/30 (Fri Aug  1 03:27:33 UTC 2025):
   ✅ SSM Agent online
   📋 Cloud-init status: done
   🏃 Runner service status: active
   ✅ Runner service is active!
🔍 Final runner status check...
📡 Checking GitHub API for registered runners...
✅ Found registered runners:
github-runner-lower-206 - online - false
📋 Getting setup logs from instance...
📋 Instance logs:
=== Cloud-init output ===
[... detailed logs ...]
✅ Step 3 Complete: Runner setup monitoring finished!
```

### 2. Runner Status Check Script

**File**: `scripts/check-runner-status.sh`

**Features**:
- 🔍 **Instance discovery** and health checks
- 🔗 **SSM connectivity** verification
- 📋 **Remote status collection** via SSM commands
- 🐙 **GitHub API integration** to check runner registration
- 🛠️ **Troubleshooting commands** provided

**Usage**:
```bash
./scripts/check-runner-status.sh lower
```

### 3. Automatic Issue Fixer

**File**: `scripts/fix-runner-issues.sh`

**Fixes**:
- 🔄 **Service restart** with proper error handling
- 📁 **Permission fixes** for runner directory
- 🔐 **Runner re-registration** with GitHub
- 🌐 **Network connectivity tests**
- 📝 **Debug information collection**

**Usage**:
```bash
./scripts/fix-runner-issues.sh lower
```

### 4. Enhanced Runner Setup Script

**File**: `infra/modules/github-runner/runner-setup.sh`

**Improvements**:
- ✅ **Detailed progress logging** at each step
- ✅ **Error handling** with exit codes
- ✅ **Token validation** before configuration
- ✅ **Multiple start methods** (service + direct)
- ✅ **Final status verification**
- ✅ **Comprehensive log files**

### 5. On-Instance Helper Scripts

**Created automatically on runner**:
- `/home/ubuntu/debug-runner.sh` - Debug runner status
- `/home/ubuntu/restart-runner.sh` - Restart runner service
- `/home/ubuntu/check-runner-github.sh` - Check GitHub connectivity
- `/home/ubuntu/monitor-runner.sh` - Health monitoring (cron job)

## How to Debug Runner Issues

### Step 1: Check Workflow Logs
Look at the GitHub Actions workflow logs for the "Create GitHub Runner" step. You'll see detailed progress and any errors.

### Step 2: Use Status Check Script
```bash
cd scripts
./check-runner-status.sh lower
```

### Step 3: Try Automatic Fix
```bash
./fix-runner-issues.sh lower
```

### Step 4: Manual Connection
```bash
# Get instance ID from status check
aws ssm start-session --target i-1234567890abcdef0

# On the instance
/home/ubuntu/debug-runner.sh
/home/ubuntu/check-runner-github.sh
```

### Step 5: Check GitHub Settings
Go to your repository → Settings → Actions → Runners to see if the runner is registered.

## Common Issues Resolved

### Issue: "No runner process found"
**Before**: Silent failure, no visibility
**After**: 
- Detailed logging shows exactly where setup fails
- Automatic retry with direct start method
- Helper scripts for manual recovery

### Issue: "Runner not appearing in GitHub"
**Before**: Had to SSH and debug manually
**After**:
- GitHub API checks during workflow
- Token validation with error messages
- Automatic re-registration capability

### Issue: "Cannot connect to runner instance"
**Before**: No way to check instance status
**After**:
- SSM connectivity monitoring
- Instance health checks
- Multiple connection methods provided

## Log Locations

### During Workflow (GitHub Actions Console)
- Real-time progress updates
- Error messages with context
- Final status summary

### On Runner Instance
- `/var/log/cloud-init-output.log` - Instance initialization
- `/var/log/runner-config.log` - Runner configuration details
- `/var/log/runner-logs/health-monitor.log` - Ongoing health checks

### S3 (if configured)
- Daily log archives uploaded automatically
- Organized by network tier and instance ID

## What This Solves

Your original issue was:
```bash
root@ip-10-0-1-206:/var/snap/amazon-ssm-agent/11320# ps aux | grep run.sh
root        3665  0.0  0.2   7012  2304 pts/1    S+   03:26   0:00 grep --color=auto run.sh
# No runner process found
```

Now you'll have:
1. **Visibility** into why the runner isn't starting
2. **Automatic fixes** for common issues
3. **Helper scripts** on the instance for manual debugging
4. **Detailed logs** showing exactly what happened during setup

The enhanced workflow will show you in the GitHub console exactly what's happening during runner setup, making it much easier to identify and fix issues.