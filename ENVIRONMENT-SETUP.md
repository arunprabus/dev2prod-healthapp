# 🌍 Environment Configuration Guide

## 📋 GitHub Environment Setup

### 1. Create GitHub Environments
Go to **Settings** → **Environments** and create:
- `dev`
- `test` 
- `prod`

### 2. Environment Variables Configuration

#### **Global Variables (Repository Level)**
| Variable | Default | Description |
|----------|---------|-------------|
| `AWS_REGION` | `ap-south-1` | AWS deployment region |
| `EKS_CLUSTER_NAME` | `health-app-cluster` | Base EKS cluster name |
| `CONTAINER_REGISTRY` | `ghcr.io` | Container registry URL |
| `REGISTRY_NAMESPACE` | `arunprabus` | Registry namespace/username |
| `TERRAFORM_VERSION` | `1.6.0` | Terraform version to use |
| `KUBECTL_TIMEOUT` | `300s` | Kubernetes operation timeout |
| `CLEANUP_DELAY` | `30` | Seconds to wait before cleanup |
| `LB_WAIT_TIME` | `60` | Load balancer readiness wait time |

#### **Environment-Specific Variables**

##### **Development Environment**
```yaml
# Repository Variables → dev environment
AWS_REGION: "ap-south-1"
EKS_CLUSTER_NAME: "health-app-dev-cluster"
CONTAINER_REGISTRY: "ghcr.io"
REGISTRY_NAMESPACE: "your-username"
KUBECTL_TIMEOUT: "180s"
CLEANUP_DELAY: "10"
LB_WAIT_TIME: "30"
```

##### **Test Environment**
```yaml
# Repository Variables → test environment
AWS_REGION: "ap-south-1"
EKS_CLUSTER_NAME: "health-app-test-cluster"
CONTAINER_REGISTRY: "ghcr.io"
REGISTRY_NAMESPACE: "your-username"
KUBECTL_TIMEOUT: "240s"
CLEANUP_DELAY: "20"
LB_WAIT_TIME: "45"
```

##### **Production Environment**
```yaml
# Repository Variables → prod environment
AWS_REGION: "us-east-1"  # Different region for prod
EKS_CLUSTER_NAME: "health-app-prod-cluster"
CONTAINER_REGISTRY: "your-private-registry.com"
REGISTRY_NAMESPACE: "production"
KUBECTL_TIMEOUT: "600s"  # Longer timeout for prod
CLEANUP_DELAY: "60"      # Longer rollback window
LB_WAIT_TIME: "120"      # More time for LB in prod
```

## 🔧 Multi-Region Setup Example

### **Asia Pacific Setup**
```yaml
# For Indian customers
AWS_REGION: "ap-south-1"        # Mumbai
EKS_CLUSTER_NAME: "health-app-apac-cluster"
```

### **US Setup**
```yaml
# For US customers
AWS_REGION: "us-east-1"         # Virginia
EKS_CLUSTER_NAME: "health-app-us-cluster"
```

### **Europe Setup**
```yaml
# For European customers
AWS_REGION: "eu-west-1"         # Ireland
EKS_CLUSTER_NAME: "health-app-eu-cluster"
```

## 🏢 Multi-Tenant Configuration

### **Customer A**
```yaml
AWS_REGION: "us-west-2"
EKS_CLUSTER_NAME: "customer-a-cluster"
REGISTRY_NAMESPACE: "customer-a"
```

### **Customer B**
```yaml
AWS_REGION: "eu-central-1"
EKS_CLUSTER_NAME: "customer-b-cluster"
REGISTRY_NAMESPACE: "customer-b"
```

## 🔐 Secrets Configuration

### **Repository Secrets**
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `SLACK_WEBHOOK_URL`

### **Environment-Specific Secrets**
Each environment can have its own AWS credentials:

#### **Development**
- `AWS_ACCESS_KEY_ID_DEV`
- `AWS_SECRET_ACCESS_KEY_DEV`

#### **Production**
- `AWS_ACCESS_KEY_ID_PROD`
- `AWS_SECRET_ACCESS_KEY_PROD`

## 🚀 Quick Setup Commands

### **1. Set Global Variables**
```bash
# Using GitHub CLI
gh variable set AWS_REGION --body "ap-south-1"
gh variable set EKS_CLUSTER_NAME --body "health-app-cluster"
gh variable set CONTAINER_REGISTRY --body "ghcr.io"
gh variable set REGISTRY_NAMESPACE --body "your-username"
```

### **2. Set Environment Variables**
```bash
# Development environment
gh variable set AWS_REGION --env dev --body "ap-south-1"
gh variable set EKS_CLUSTER_NAME --env dev --body "health-app-dev-cluster"

# Production environment
gh variable set AWS_REGION --env prod --body "us-east-1"
gh variable set EKS_CLUSTER_NAME --env prod --body "health-app-prod-cluster"
```

## 📊 Benefits of This Approach

### **✅ Flexibility**
- Deploy to any AWS region
- Support multiple customers/tenants
- Easy environment customization

### **✅ Security**
- Environment-specific credentials
- No hardcoded values in code
- Centralized secret management

### **✅ Scalability**
- Add new environments easily
- Support multi-region deployments
- Customer-specific configurations

### **✅ Maintainability**
- Single workflow for all environments
- Configuration-driven deployments
- Easy to update and manage

## 🎯 Best Practices

1. **Use descriptive variable names**
2. **Set sensible defaults** for fallback
3. **Document all variables** and their purpose
4. **Use environment-specific values** for production
5. **Keep secrets separate** from variables
6. **Test configurations** in dev first
7. **Use consistent naming** across environments