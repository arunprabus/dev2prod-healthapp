# 🔧 GitHub Configuration Guide

## 📋 **Complete GitHub Secrets & Variables Setup**

### 🔐 **Required Secrets**
Go to **Repository Settings** → **Secrets and variables** → **Actions** → **Secrets**

```yaml
# AWS Authentication
AWS_ACCESS_KEY_ID: "AKIA..."
AWS_SECRET_ACCESS_KEY: "xyz123..."

# K8s Cluster Access
KUBECONFIG: "Base64 encoded kubeconfig file"

# Infrastructure Access
SSH_PUBLIC_KEY: "ssh-rsa AAAAB3..."

# Terraform State
TF_STATE_BUCKET: "health-app-terraform-state"

# Optional Notifications
SLACK_WEBHOOK_URL: "https://hooks.slack.com/..."
```

### ⚙️ **K8s Configuration Variables**
Go to **Repository Settings** → **Secrets and variables** → **Actions** → **Variables**

```yaml
# Core Infrastructure
AWS_REGION: "ap-south-1"
K8S_CLUSTER_NAME: "health-app-cluster"

# Container Registry
CONTAINER_REGISTRY: "your-account.dkr.ecr.ap-south-1.amazonaws.com"
REGISTRY_NAMESPACE: "health-app"

# Tool Versions
TERRAFORM_VERSION: "1.6.0"
KUBECTL_VERSION: "latest"

# K8s Operations
KUBECTL_TIMEOUT: "300s"
MIN_REPLICAS: "1"
MAX_REPLICAS: "5"
CLEANUP_DELAY: "30"
LB_WAIT_TIME: "60"
HEALTH_CHECK_RETRIES: "5"

# Cost Management
BUDGET_EMAIL: "your-email@domain.com"
BUDGET_REGIONS: "us-east-1,ap-south-1"

# Tagging & Naming
PROJECT_NAME: "health-app"
TEAM_NAME: "devops-team"
COST_CENTER: "engineering"
DATA_CLASSIFICATION: "internal"
COMPLIANCE_SCOPE: "hipaa"
BACKUP_REQUIRED: "true"
MONITORING_LEVEL: "medium"
```

## 🚀 **Environment-Specific Configuration**

### **Development Environment**
```yaml
# Variables for dev environment
AWS_REGION: "ap-south-1"
K8S_CLUSTER_NAME: "health-app-dev"
CONTAINER_REGISTRY: "ghcr.io"
REGISTRY_NAMESPACE: "dev-team"
MIN_REPLICAS: "1"
MAX_REPLICAS: "3"
KUBECTL_TIMEOUT: "180s"
CLEANUP_DELAY: "10"
LB_WAIT_TIME: "30"
```

### **Test Environment**
```yaml
# Variables for test environment
AWS_REGION: "ap-south-1"
K8S_CLUSTER_NAME: "health-app-test"
CONTAINER_REGISTRY: "ghcr.io"
REGISTRY_NAMESPACE: "test-team"
MIN_REPLICAS: "2"
MAX_REPLICAS: "5"
KUBECTL_TIMEOUT: "240s"
CLEANUP_DELAY: "20"
LB_WAIT_TIME: "45"
```

### **Production Environment**
```yaml
# Variables for prod environment
AWS_REGION: "us-east-1"
K8S_CLUSTER_NAME: "health-app-prod"
CONTAINER_REGISTRY: "your-company.dkr.ecr.us-east-1.amazonaws.com"
REGISTRY_NAMESPACE: "production"
MIN_REPLICAS: "3"
MAX_REPLICAS: "20"
KUBECTL_TIMEOUT: "600s"
CLEANUP_DELAY: "120"
LB_WAIT_TIME: "180"
```

## 🛠️ **Setup Commands**

### **Using GitHub CLI**
```bash
# Install GitHub CLI
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt update && sudo apt install gh

# Login to GitHub
gh auth login

# Set secrets
gh secret set AWS_ACCESS_KEY_ID --body "AKIA..."
gh secret set AWS_SECRET_ACCESS_KEY --body "xyz123..."
gh secret set SSH_PUBLIC_KEY --body "$(cat ~/.ssh/aws-key.pub)"
gh secret set TF_STATE_BUCKET --body "health-app-terraform-state"

# Set variables
gh variable set AWS_REGION --body "ap-south-1"
gh variable set K8S_CLUSTER_NAME --body "health-app-cluster"
gh variable set CONTAINER_REGISTRY --body "your-account.dkr.ecr.ap-south-1.amazonaws.com"
gh variable set REGISTRY_NAMESPACE --body "health-app"
gh variable set MIN_REPLICAS --body "1"
gh variable set MAX_REPLICAS --body "5"
gh variable set KUBECTL_TIMEOUT --body "300s"
gh variable set BUDGET_EMAIL --body "your-email@domain.com"
```

### **Using GitHub Web Interface**
1. Go to your repository
2. Click **Settings** tab
3. Click **Secrets and variables** → **Actions**
4. Add secrets in **Secrets** tab
5. Add variables in **Variables** tab

## 🔄 **Workflow Variable Usage**

### **In GitHub Actions Workflows**
```yaml
# Using secrets
env:
  AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
  AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}

# Using variables
env:
  AWS_REGION: ${{ vars.AWS_REGION }}
  K8S_CLUSTER_NAME: ${{ vars.K8S_CLUSTER_NAME }}
  MIN_REPLICAS: ${{ vars.MIN_REPLICAS }}
  MAX_REPLICAS: ${{ vars.MAX_REPLICAS }}

# Using with defaults
env:
  KUBECTL_TIMEOUT: ${{ vars.KUBECTL_TIMEOUT || '300s' }}
  BUDGET_EMAIL: ${{ vars.BUDGET_EMAIL || 'admin@example.com' }}
```

### **In Scripts**
```bash
# Environment variables are automatically available
echo "Deploying to region: $AWS_REGION"
echo "Cluster name: $K8S_CLUSTER_NAME"
echo "Min replicas: $MIN_REPLICAS"
echo "Max replicas: $MAX_REPLICAS"

# Using in kubectl commands
kubectl scale deployment health-api --replicas=$MIN_REPLICAS -n health-app-dev
kubectl wait --timeout=$KUBECTL_TIMEOUT --for=condition=ready pods -l app=health-api
```

## 🌍 **Multi-Region Configuration**

### **US Region Setup**
```yaml
AWS_REGION: "us-east-1"
K8S_CLUSTER_NAME: "health-app-us"
CONTAINER_REGISTRY: "123456789.dkr.ecr.us-east-1.amazonaws.com"
REGISTRY_NAMESPACE: "us-production"
```

### **EU Region Setup**
```yaml
AWS_REGION: "eu-west-1"
K8S_CLUSTER_NAME: "health-app-eu"
CONTAINER_REGISTRY: "123456789.dkr.ecr.eu-west-1.amazonaws.com"
REGISTRY_NAMESPACE: "eu-production"
```

### **APAC Region Setup**
```yaml
AWS_REGION: "ap-south-1"
K8S_CLUSTER_NAME: "health-app-apac"
CONTAINER_REGISTRY: "123456789.dkr.ecr.ap-south-1.amazonaws.com"
REGISTRY_NAMESPACE: "apac-production"
```

## 🔒 **Security Best Practices**

### **Secrets Management**
- ✅ **Never commit secrets** to repository
- ✅ **Use GitHub Secrets** for sensitive data
- ✅ **Rotate credentials** regularly
- ✅ **Limit secret access** to necessary workflows
- ✅ **Use environment-specific** secrets when needed

### **Variables Management**
- ✅ **Use Variables** for non-sensitive configuration
- ✅ **Environment-specific** variables for different deployments
- ✅ **Default values** in workflows for flexibility
- ✅ **Consistent naming** across environments

## 🧪 **Testing Configuration**

### **Validate Secrets**
```bash
# Test AWS credentials
aws sts get-caller-identity

# Test kubeconfig
kubectl cluster-info

# Test SSH key
ssh-keygen -l -f ~/.ssh/aws-key.pub
```

### **Validate Variables**
```bash
# Check if variables are set
echo "Region: $AWS_REGION"
echo "Cluster: $K8S_CLUSTER_NAME"
echo "Registry: $CONTAINER_REGISTRY"
echo "Namespace: $REGISTRY_NAMESPACE"
```

## 📊 **Configuration Templates**

### **Minimal Setup (Free Tier)**
```yaml
# Secrets
AWS_ACCESS_KEY_ID: "AKIA..."
AWS_SECRET_ACCESS_KEY: "xyz123..."
SSH_PUBLIC_KEY: "ssh-rsa AAAAB3..."

# Variables
AWS_REGION: "ap-south-1"
K8S_CLUSTER_NAME: "health-app-cluster"
MIN_REPLICAS: "1"
MAX_REPLICAS: "3"
```

### **Production Setup**
```yaml
# Secrets
AWS_ACCESS_KEY_ID: "AKIA..."
AWS_SECRET_ACCESS_KEY: "xyz123..."
KUBECONFIG: "Base64 encoded kubeconfig"
SSH_PUBLIC_KEY: "ssh-rsa AAAAB3..."
TF_STATE_BUCKET: "health-app-terraform-state"
SLACK_WEBHOOK_URL: "https://hooks.slack.com/..."

# Variables
AWS_REGION: "us-east-1"
K8S_CLUSTER_NAME: "health-app-prod"
CONTAINER_REGISTRY: "123456789.dkr.ecr.us-east-1.amazonaws.com"
REGISTRY_NAMESPACE: "production"
MIN_REPLICAS: "3"
MAX_REPLICAS: "20"
KUBECTL_TIMEOUT: "600s"
BUDGET_EMAIL: "ops-team@company.com"
```

## 🔧 **Troubleshooting**

### **Common Issues**
```bash
# Secret not found
Error: Secret AWS_ACCESS_KEY_ID not found
Solution: Add secret in GitHub repository settings

# Variable not set
Error: Variable AWS_REGION is empty
Solution: Add variable in GitHub repository settings

# Invalid kubeconfig
Error: Unable to connect to cluster
Solution: Update KUBECONFIG secret with valid base64 encoded config
```

### **Debug Commands**
```bash
# List all secrets (names only)
gh secret list

# List all variables
gh variable list

# Test workflow with debug
gh workflow run infrastructure.yml --ref main
```

This configuration ensures your K8s infrastructure workflows have all necessary secrets and variables for automated deployment and management!