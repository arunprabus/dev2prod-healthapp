# 🖥️ Session Manager & K3s Connection Guide

## Overview

All infrastructure instances now include **AWS Systems Manager Session Manager** support for secure, browser-based terminal access without SSH keys or bastion hosts.

## 🔧 What's Included

### ✅ K3s Cluster Instances
- **Session Manager Agent**: Pre-installed and configured
- **IAM Role**: `AmazonSSMManagedInstanceCore` policy attached
- **SSH Key**: Same key as GitHub runners for consistency
- **kubectl**: Pre-installed for local management

### ✅ GitHub Runner Instances  
- **Session Manager Agent**: Pre-installed and configured
- **IAM Role**: `AmazonSSMManagedInstanceCore` policy attached
- **SSH Key**: Same key as K3s instances
- **kubectl**: Pre-installed for K8s operations
- **Docker**: Pre-installed for container operations

## 🚀 Connection Methods

### 1. Session Manager (Recommended)
```bash
# Connect to K3s instance
aws ssm start-session --target i-1234567890abcdef0

# Or use the helper script
./scripts/k3s-connect.sh dev session-manager
./scripts/k3s-connect.sh prod ssm
```

### 2. SSH (Traditional)
```bash
# Connect to K3s instance
ssh -i ~/.ssh/k3s-key ubuntu@<PUBLIC_IP>

# Or use the helper script
./scripts/k3s-connect.sh dev ssh
```

### 3. kubectl (Direct K8s Access)
```bash
# Setup kubectl connection
./scripts/k3s-connect.sh dev kubectl
./scripts/k3s-connect.sh prod k8s

# Then use kubectl normally
kubectl get pods -n health-app-dev
kubectl get services -n health-app-prod
```

## 🔗 Connection Helper Script

The `scripts/k3s-connect.sh` script provides unified access to all connection methods:

```bash
# Usage
./scripts/k3s-connect.sh <environment> [action]

# Examples
./scripts/k3s-connect.sh dev ssh           # SSH to dev K3s
./scripts/k3s-connect.sh prod ssm          # Session Manager to prod K3s  
./scripts/k3s-connect.sh test kubectl     # kubectl to test environment
./scripts/k3s-connect.sh monitoring k8s   # kubectl to monitoring cluster
```

### Supported Environments
- `dev` - Development K3s cluster (lower network)
- `test` - Test K3s cluster (lower network)  
- `prod` - Production K3s cluster (higher network)
- `monitoring` - Monitoring K3s cluster (monitoring network)

### Supported Actions
- `ssh` - SSH connection using key-based authentication
- `session-manager` / `ssm` - Browser-based Session Manager
- `kubectl` / `k8s` - Direct kubectl access with auto-configured kubeconfig

## 🛡️ Security Benefits

### Session Manager Advantages
- ✅ **No SSH Keys Required**: Browser-based access
- ✅ **No Bastion Hosts**: Direct connection through AWS
- ✅ **Audit Logging**: All sessions logged in CloudTrail
- ✅ **IAM-Based Access**: Fine-grained permissions
- ✅ **No Public SSH**: Reduced attack surface

### Consistent Key Management
- ✅ **Single Key Pair**: Same key for K3s and GitHub runners
- ✅ **Easy Access**: GitHub runners can SSH to K3s instances
- ✅ **Automated Deployment**: No manual key distribution

## 🔧 GitHub Actions Integration

### Automatic kubeconfig Management
```yaml
# In GitHub Actions workflows
- name: Connect to K3s
  run: |
    # Kubeconfig automatically available from secrets
    kubectl get nodes
    kubectl get pods -n health-app-${{ env.ENVIRONMENT }}
```

### Environment-Specific Secrets
- `KUBECONFIG_DEV` - Development cluster access
- `KUBECONFIG_TEST` - Test cluster access  
- `KUBECONFIG_PROD` - Production cluster access
- `KUBECONFIG_MONITORING` - Monitoring cluster access

## 🚨 Troubleshooting

### Session Manager Not Working
```bash
# Check if SSM agent is running
sudo systemctl status snap.amazon-ssm-agent.amazon-ssm-agent

# Restart SSM agent
sudo systemctl restart snap.amazon-ssm-agent.amazon-ssm-agent

# Check IAM role attachment
aws sts get-caller-identity
```

### SSH Connection Issues
```bash
# Check security group rules
aws ec2 describe-security-groups --group-ids sg-xxxxxxxxx

# Test SSH key
ssh -i ~/.ssh/k3s-key -o StrictHostKeyChecking=no ubuntu@<PUBLIC_IP>
```

### kubectl Connection Issues
```bash
# Download fresh kubeconfig
./scripts/k3s-connect.sh dev kubectl

# Test cluster connectivity
kubectl cluster-info
kubectl get nodes
```

## 💡 Best Practices

### For Development
- Use **Session Manager** for secure access
- Use **kubectl helper** for K8s operations
- Keep SSH keys as backup method

### For Production
- **Always use Session Manager** for production access
- **Audit all connections** through CloudTrail
- **Limit IAM permissions** to specific users/roles

### For CI/CD
- Use **GitHub Secrets** for kubeconfig
- **Never expose** SSH keys in workflows
- **Use environment-specific** connections

## 📊 Cost Impact

### Session Manager
- **Cost**: $0 (included in AWS Free Tier)
- **Data Transfer**: Minimal (terminal sessions)
- **Storage**: CloudTrail logs (optional)

### Infrastructure Changes
- **IAM Policies**: No additional cost
- **SSM Agent**: No additional cost  
- **Security Groups**: No additional cost

**Total Additional Cost: $0/month**

## 🔄 Migration from Old Setup

If you have existing infrastructure without Session Manager:

1. **Redeploy Infrastructure**: Run the deploy action again
2. **Verify SSM Agent**: Check agent status on instances
3. **Test Connections**: Use the helper script to verify access
4. **Update Workflows**: Use new connection methods in CI/CD

The infrastructure is designed to be **idempotent** - safe to redeploy without data loss.