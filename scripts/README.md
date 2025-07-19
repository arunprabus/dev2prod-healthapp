# Scripts Directory

This directory contains various scripts for managing the Health App infrastructure.

## Key Scripts

### Kubeconfig Management
- `setup-kubeconfig.sh` - Generate kubeconfig for connecting to K3s clusters
- `fix-kubeconfig-now.bat` - Quick fix for kubeconfig issues on Windows
- `generate-kubeconfig.bat` / `generate-kubeconfig.ps1` - Generate kubeconfig on Windows

### GitHub Secrets Management
- `update-github-secrets.sh` - Update GitHub secrets from bash
- `update-github-secrets.ps1` - Update GitHub secrets from PowerShell
- `update-github-secrets.bat` - Update GitHub secrets from Windows command prompt
- `update-secrets.bat` - Interactive menu for managing GitHub secrets

### AWS Management
- `aws-budget-setup.sh` - Set up AWS budget alerts
- `aws-resource-audit.sh` - Audit AWS resources
- `aws-resource-cleanup.sh` - Clean up AWS resources
- `cost-breakdown.sh` - Show AWS cost breakdown
- `cost-cleanup-auto.sh` - Automatically clean up resources to reduce costs

### Kubernetes Management
- `k3s-health-check.sh` - Check K3s cluster health
- `k8s-auto-scale.sh` - Auto-scale Kubernetes resources
- `k8s-health-check.sh` - Check Kubernetes health

### Deployment
- `deploy-nodejs-app.sh` - Deploy Node.js application
- `deploy-with-secrets.sh` - Deploy with secrets
- `blue_green_status.sh` - Check blue-green deployment status

## Subdirectories

- `kubeconfig/` - Kubeconfig files for connecting to Kubernetes clusters

## Usage

Most scripts include usage instructions when run without arguments. For example:

```bash
./setup-kubeconfig.sh
# Shows usage: ./setup-kubeconfig.sh <environment> <cluster-ip>
```

For Windows scripts, use:

```cmd
update-secrets.bat
# Shows interactive menu for managing GitHub secrets
```