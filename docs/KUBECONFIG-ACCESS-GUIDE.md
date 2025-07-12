# 🔑 Kubeconfig Access Guide

## 🎯 Two Ways to Access Kubeconfig

### Method 1: Kubeconfig Access Workflow (Recommended)
1. Go to **Actions** → **Kubeconfig Access**
2. Click **Run workflow**
3. Select:
   - **Environment**: `dev`, `test`, `prod`, or `monitoring`
   - **Action**: Choose what you want to do:
     - `download` - View kubeconfig content
     - `test-connection` - Test cluster connectivity
     - `get-nodes` - List cluster nodes
     - `get-pods` - List all pods
4. Click **Run workflow**

### Method 2: Script Executor (What you used)
1. Go to **Actions** → **Script Executor**
2. Select:
   - **Script**: `download-kubeconfig.sh`
   - **Environment**: `dev`
   - **Action**: Leave empty or use `ssh`
3. Click **Run workflow**

## 🔧 Your Current Status

✅ **Kubeconfig Downloaded**: Successfully got kubeconfig-dev.yaml
⚠️ **Connection Failed**: Cluster may still be initializing

## 🚀 Next Steps

### Option 1: Wait and Test Again
The cluster might need more time to initialize. Try:
1. **Actions** → **Kubeconfig Access**
2. Environment: `dev`
3. Action: `test-connection`

### Option 2: Check Cluster Status
1. **Actions** → **Script Executor**
2. Script: `k3s-health-check.sh`
3. Environment: `dev`

### Option 3: Use SSH to Check Manually
1. **Actions** → **Script Executor**
2. Script: `k3s-connect.sh`
3. Environment: `dev`
4. Action: `ssh`

## 💡 Troubleshooting

**If connection keeps failing:**
1. Check if infrastructure is fully deployed
2. Wait 5-10 minutes after deployment
3. Verify K3s service is running on the instance

**Your workflow usage was correct!** The issue is likely timing - K3s needs time to fully initialize.