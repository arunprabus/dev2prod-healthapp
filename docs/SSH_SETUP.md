# 🔑 SSH Key Setup for K3s Clusters

## Quick Setup

### 1. Generate SSH Key Pair
```bash
# Generate new SSH key
./scripts/generate-ssh-key.sh

# Or manually:
ssh-keygen -t rsa -b 4096 -f ~/.ssh/k3s-key -N "" -C "k3s-cluster-access"
```

### 2. Configure GitHub Secrets
Go to **Settings** → **Secrets and variables** → **Actions**:

**Required Secrets:**
```yaml
SSH_PUBLIC_KEY: "ssh-rsa AAAAB3NzaC1yc2EAAAA... (from ~/.ssh/k3s-key.pub)"
SSH_PRIVATE_KEY: "-----BEGIN OPENSSH PRIVATE KEY----- ... (from ~/.ssh/k3s-key)"
```

### 3. Deploy Infrastructure
```bash
# Deploy via GitHub Actions
Actions → Core Infrastructure → action: "deploy" → environment: "lower"

# Kubeconfig secrets are automatically created:
# - KUBECONFIG_DEV
# - KUBECONFIG_TEST  
# - KUBECONFIG_LOWER
```

## Manual Kubeconfig Setup

### Download Kubeconfig
```bash
# Get cluster IP from Terraform output
CLUSTER_IP="1.2.3.4"  # From GitHub Actions output

# Download kubeconfig
./scripts/setup-kubeconfig.sh dev $CLUSTER_IP ~/.ssh/k3s-key

# Use kubeconfig
export KUBECONFIG=$PWD/kubeconfig-dev.yaml
kubectl get nodes
```

### Create GitHub Secret
```bash
# Automatic (requires GITHUB_TOKEN)
export GITHUB_TOKEN="your_token_here"
./scripts/kubeconfig-to-github-secret.sh dev $CLUSTER_IP ~/.ssh/k3s-key

# Manual
base64 -w 0 kubeconfig-dev.yaml
# Copy output to GitHub Secret: KUBECONFIG_DEV
```

## Terraform Integration

### Updated Configuration
```hcl
# SSH key from variable (not file)
resource "aws_key_pair" "main" {
  key_name   = "${local.name_prefix}-key"
  public_key = var.ssh_public_key  # From GitHub Secret
  tags       = local.tags
}

# Kubeconfig accessible for download
resource "aws_instance" "k3s" {
  # ... other config
  user_data = <<-EOF
    #!/bin/bash
    # Install K3s
    curl -sfL https://get.k3s.io | sh -
    
    # Make kubeconfig downloadable
    chmod 644 /etc/rancher/k3s/k3s.yaml
  EOF
}
```

### Terraform Outputs
```hcl
output "kubeconfig_setup_commands" {
  value = [
    "scp -i ~/.ssh/k3s-key ubuntu@${aws_instance.k3s.public_ip}:/etc/rancher/k3s/k3s.yaml kubeconfig-${var.environment}.yaml",
    "sed -i 's/127.0.0.1/${aws_instance.k3s.public_ip}/' kubeconfig-${var.environment}.yaml",
    "export KUBECONFIG=$PWD/kubeconfig-${var.environment}.yaml",
    "kubectl get nodes"
  ]
}
```

## Security Benefits

### Corporate vs Learning Approach
| Aspect | Learning (Current) | Corporate Standard |
|--------|-------------------|-------------------|
| **Auth Method** | SSH + kubeconfig download | Service Account tokens |
| **Secret Storage** | GitHub Secrets | HashiCorp Vault |
| **Access Level** | Full cluster admin | Namespace-specific RBAC |
| **Key Rotation** | Manual | Automated (30-90 days) |

### Current Security Features
- ✅ **SSH key-based access** (not password)
- ✅ **Kubeconfig over encrypted SSH** (not plain HTTP)
- ✅ **GitHub Secrets encryption** (not plain text)
- ✅ **Temporary local files** (cleaned up after use)
- ✅ **Environment isolation** (separate kubeconfigs)

## Troubleshooting

### SSH Connection Issues
```bash
# Check SSH key permissions
chmod 600 ~/.ssh/k3s-key

# Test SSH connection
ssh -i ~/.ssh/k3s-key ubuntu@CLUSTER_IP

# Check security group allows SSH (port 22)
```

### Kubeconfig Issues
```bash
# Verify kubeconfig format
kubectl config view --kubeconfig=kubeconfig-dev.yaml

# Test connection
kubectl get nodes --kubeconfig=kubeconfig-dev.yaml --request-timeout=10s

# Check K3s service status
ssh -i ~/.ssh/k3s-key ubuntu@CLUSTER_IP "sudo systemctl status k3s"
```

### GitHub Actions Issues
```bash
# Check workflow permissions
# Settings → Actions → General → Workflow permissions: Read and write

# Verify secrets exist
# Settings → Secrets → SSH_PUBLIC_KEY and SSH_PRIVATE_KEY

# Check workflow logs for specific errors
```

## Next Steps: Production Security

### Phase 1: Service Accounts (Recommended)
```yaml
# Create namespace-specific service account
apiVersion: v1
kind: ServiceAccount
metadata:
  name: github-actions-sa
  namespace: health-app-dev
---
# Limited permissions (not cluster-admin)
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: health-app-dev
  name: deployer-role
rules:
- apiGroups: ["apps", ""]
  resources: ["deployments", "services", "pods"]
  verbs: ["get", "list", "create", "update", "patch", "delete"]
```

### Phase 2: OIDC Integration (Production)
- AWS EKS with IAM roles for service accounts (IRSA)
- Azure AKS with Azure AD integration
- Google GKE with Google Service Accounts
- HashiCorp Vault for secret management