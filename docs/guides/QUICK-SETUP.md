# 🚀 Quick Setup Guide - New Architecture

## 📋 Prerequisites
- AWS Account with Free Tier
- SSH Key Pair generated
- GitHub CLI installed (optional)

## 🔧 Step 1: Configure GitHub Secrets

### **dev2prod-healthapp Repository**
```bash
# Navigate to Settings → Secrets and variables → Actions → Secrets

# Environment-specific kubeconfig (REQUIRED)
KUBECONFIG_DEV: "Base64 encoded dev cluster kubeconfig"
KUBECONFIG_TEST: "Base64 encoded test cluster kubeconfig"
KUBECONFIG_PROD: "Base64 encoded prod cluster kubeconfig"
KUBECONFIG_MONITORING: "Base64 encoded monitoring cluster kubeconfig"
KUBECONFIG: "Base64 encoded fallback kubeconfig"

# Infrastructure
SSH_PUBLIC_KEY: "ssh-rsa AAAAB3..."
TF_STATE_BUCKET: "health-app-terraform-state"
```

### **health-api Repository**
```bash
# For triggering deployments
INFRA_REPO_TOKEN: "github-personal-access-token"
```

## 🔧 Step 2: Configure GitHub Variables

### **dev2prod-healthapp Repository**
```bash
# Navigate to Settings → Secrets and variables → Actions → Variables

AWS_REGION: "ap-south-1"
K8S_CLUSTER_NAME: "health-app-cluster"
CONTAINER_REGISTRY: "docker.io"
REGISTRY_NAMESPACE: "your-username"
TERRAFORM_VERSION: "1.6.0"
```

## 🚀 Step 3: Deploy Infrastructure

```bash
# Single environment
Actions → Core Infrastructure → action: "deploy" → environment: "dev"

# All environments
Actions → Core Infrastructure → action: "deploy" → environment: "all"
```

## 🔗 Step 4: Setup Kubeconfig

After infrastructure deployment:
```bash
# Get cluster IPs from workflow output
# Update secrets with generated kubeconfig files
```

## 📦 Step 5: Deploy Applications

```bash
# Via GitOps (Recommended)
# Push to health-api repo → Auto-deploys

# Or Manual
Actions → Core Deployment → Manual deployment
```

## 🛡️ Step 6: Apply Network Policies

```bash
kubectl apply -f k8s/network-policies.yaml
```

## ✅ Step 7: Verify Deployment

```bash
# Check all environments
Actions → Core Operations → action: "monitor"

# Check specific environment
kubectl get pods -n health-app-dev
kubectl get pods -n health-app-test
kubectl get pods -n health-app-prod
kubectl get pods -n monitoring
```

## 🧹 Cleanup (When Done)

```bash
Actions → Core Infrastructure → action: "destroy" → environment: "all" → confirm: "DESTROY"
```

---

**🎯 Result: Multi-network architecture with complete environment isolation!**