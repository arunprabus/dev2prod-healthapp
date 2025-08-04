# 🔧 Manual Kubeconfig Fix Guide

## 🚨 Issue: K3s Kubeconfig Not Ready

The infrastructure deployment completed successfully, but the K3s cluster initialization is taking longer than expected. The kubeconfig file isn't being uploaded to S3 within the timeout window.

## ✅ Infrastructure Status
- **K3s Cluster IP**: `13.232.6.250`
- **GitHub Runner IP**: `65.0.85.49`
- **Environment**: `dev`
- **Network**: `lower` (10.10.0.0/16)

## 🔧 Manual Fix Steps

### Option 1: Windows Batch Script
```bash
cd scripts
./manual-kubeconfig-fix.bat
```

### Option 2: PowerShell Script (Recommended)
```powershell
cd scripts
./manual-kubeconfig-fix.ps1
```

### Option 3: Manual Commands
```bash
# 1. Test SSH connection
ssh -i ~/.ssh/k3s-key -o StrictHostKeyChecking=no ubuntu@13.232.6.250 "echo 'Connected'"

# 2. Check K3s service
ssh -i ~/.ssh/k3s-key -o StrictHostKeyChecking=no ubuntu@13.232.6.250 "sudo systemctl status k3s"

# 3. Download kubeconfig
scp -i ~/.ssh/k3s-key -o StrictHostKeyChecking=no ubuntu@13.232.6.250:/etc/rancher/k3s/k3s.yaml kubeconfig-dev.yaml

# 4. Update server IP
sed -i 's/127.0.0.1/13.232.6.250/g' kubeconfig-dev.yaml

# 5. Test connection
export KUBECONFIG=kubeconfig-dev.yaml
kubectl cluster-info

# 6. Create GitHub secret
base64 -w 0 kubeconfig-dev.yaml > kubeconfig-base64.txt
```

## 🔐 GitHub Secret Setup

1. Go to: https://github.com/arunprabus/dev2prod-healthapp/settings/secrets/actions
2. Click **"New repository secret"**
3. **Name**: `KUBECONFIG_DEV`
4. **Value**: Copy content from `kubeconfig-base64.txt`
5. Click **"Add secret"**

## 🚀 Next Steps

After adding the GitHub secret:

1. **Deploy Application**:
   ```
   Actions → Core Deployment
   app: health-api
   image: arunprabusiva/health-api:latest
   environment: dev
   runner_type: aws
   ```

2. **Verify Deployment**:
   ```bash
   kubectl get pods -n health-app-dev
   kubectl get services -n health-app-dev
   ```

## 🔍 Troubleshooting

### SSH Connection Issues
```bash
# Check security group allows SSH (port 22)
aws ec2 describe-security-groups --group-ids sg-xxx

# Verify SSH key permissions
chmod 600 ~/.ssh/k3s-key
```

### K3s Service Issues
```bash
# Check K3s logs
ssh -i ~/.ssh/k3s-key ubuntu@13.232.6.250 "sudo journalctl -u k3s -n 50"

# Restart K3s if needed
ssh -i ~/.ssh/k3s-key ubuntu@13.232.6.250 "sudo systemctl restart k3s"
```

### Kubeconfig Issues
```bash
# Verify kubeconfig format
kubectl config view --kubeconfig=kubeconfig-dev.yaml

# Test API server connectivity
kubectl cluster-info --kubeconfig=kubeconfig-dev.yaml
```

## 💡 Why This Happened

The automated kubeconfig setup has a 5-minute timeout, but K3s installation can take 6-8 minutes on t2.micro instances due to:
- Limited CPU/memory resources
- Container image downloads
- Service initialization time

The manual fix bypasses the timeout and ensures proper kubeconfig generation.

## ✅ Expected Result

After manual fix:
- ✅ Working kubeconfig file
- ✅ GitHub secret `KUBECONFIG_DEV` created
- ✅ Ready for application deployment
- ✅ K3s cluster fully operational