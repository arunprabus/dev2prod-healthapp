# 🔧 Kubeconfig Setup Guide

## **Simple 3-Step Process**

### **Step 1: Deploy Infrastructure**
```bash
# Deploy your network (lower/higher/monitoring)
Actions → Core Infrastructure → action: "deploy" → environment: "lower"
```

### **Step 2: Generate Kubeconfig**
```bash
# After deployment, get the cluster IP from workflow output
# Then run:
./scripts/generate-kubeconfig.sh lower 1.2.3.4

# Or generate all at once:
./scripts/setup-all-kubeconfigs.sh
```

### **Step 3: Add to GitHub Secrets**
1. Go to **Settings** → **Secrets and variables** → **Actions**
2. Click **New repository secret**
3. Add these secrets:

| Secret Name | Environment | Description |
|-------------|-------------|-------------|
| `KUBECONFIG_LOWER` | Dev + Test | Lower network kubeconfig |
| `KUBECONFIG_HIGHER` | Production | Higher network kubeconfig |
| `KUBECONFIG_MONITORING` | Monitoring | Monitoring network kubeconfig |

## **Network Architecture**

```yaml
# Lower Network (10.0.0.0/16)
Environments: dev, test
Cluster IP: Get from terraform output
Secret: KUBECONFIG_LOWER

# Higher Network (10.1.0.0/16) 
Environments: prod
Cluster IP: Get from terraform output
Secret: KUBECONFIG_HIGHER

# Monitoring Network (10.3.0.0/16)
Environments: monitoring
Cluster IP: Get from terraform output
Secret: KUBECONFIG_MONITORING
```

## **Troubleshooting**

### **SSH Connection Failed**
```bash
# Check SSH key exists
ls -la ~/.ssh/aws-key

# Test SSH manually
ssh -i ~/.ssh/aws-key ubuntu@CLUSTER_IP

# Check security group allows SSH (port 22)
```

### **K3s Token Not Found**
```bash
# Wait 2-3 minutes after deployment
# K3s needs time to initialize

# Check K3s status manually
ssh -i ~/.ssh/aws-key ubuntu@CLUSTER_IP
sudo systemctl status k3s
```

### **Cluster IP Not Available**
```bash
# Check terraform output
cd infra
terraform output k3s_instance_ip

# If empty, infrastructure may have failed
# Check workflow logs
```

## **Manual Kubeconfig Creation**

If scripts fail, create manually:

```bash
# 1. Get K3s token
ssh -i ~/.ssh/aws-key ubuntu@CLUSTER_IP
sudo cat /var/lib/rancher/k3s/server/node-token

# 2. Create kubeconfig
cat > ~/.kube/config-ENV << EOF
apiVersion: v1
kind: Config
clusters:
- cluster:
    server: https://CLUSTER_IP:6443
    insecure-skip-tls-verify: true
  name: health-app-ENV
contexts:
- context:
    cluster: health-app-ENV
    user: health-app-ENV
  name: health-app-ENV
current-context: health-app-ENV
users:
- name: health-app-ENV
  user:
    token: K3S_TOKEN_HERE
EOF

# 3. Encode for GitHub
base64 -w 0 ~/.kube/config-ENV
```

## **Verification**

```bash
# Test kubeconfig locally
export KUBECONFIG=~/.kube/config-lower
kubectl get nodes

# Test in GitHub Actions
# Deploy an app and check if it connects to the right cluster
```

## **Benefits of Manual Approach**

✅ **More Reliable**: No complex GitHub API permissions needed  
✅ **Better Security**: You control when/how secrets are added  
✅ **Easier Debugging**: Clear error messages  
✅ **Flexible**: Works with any CI/CD system  
✅ **Transparent**: You see exactly what's being created