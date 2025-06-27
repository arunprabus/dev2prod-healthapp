# 🌍 Environment Configuration Guide
# Environment Setup Guide

This guide provides instructions for setting up the different environments and GitHub configuration for the Health App infrastructure.

## Environment Architecture

The Health App uses three distinct environments:

1. **Lower Environment (Dev/Test)**
   - Shared VPC (10.0.0.0/16)
   - Dev uses subnets 10.0.101.0/24, 10.0.102.0/24 (public) and 10.0.1.0/24, 10.0.2.0/24 (private)
   - Test uses subnets 10.0.103.0/24, 10.0.104.0/24 (public) and 10.0.3.0/24, 10.0.4.0/24 (private)
   - Used for development and testing

2. **Higher Environment (Prod)**
   - Isolated VPC (10.1.0.0/16)
   - Uses subnets 10.1.101.0/24, 10.1.102.0/24, 10.1.103.0/24 (public) and 10.1.1.0/24, 10.1.2.0/24, 10.1.3.0/24 (private)
   - Used for production workloads

3. **Monitoring Environment**
   - Dedicated VPC (10.3.0.0/16)
   - Uses subnets 10.3.101.0/24, 10.3.102.0/24 (public) and 10.3.1.0/24, 10.3.2.0/24 (private)
   - Connected to both Lower and Higher environments via VPC peering
   - Hosts monitoring tools like Splunk, Prometheus, etc.

## GitHub Configuration

### GitHub Environments

Create the following GitHub environments with appropriate protection rules:

1. **dev**
   - No approval required
   - No wait timer

2. **test**
   - Optional: Require approval from one reviewer
   - Optional: 5-minute wait timer

3. **prod**
   - Require approval from one or more reviewers
   - Optional: 10-minute wait timer
   - Limit deployment to `main` branch

4. **monitoring**
   - Require approval from one or more reviewers
   - Optional: 5-minute wait timer

### GitHub Secrets

Add the following secrets to your repository:

1. **Repository Secrets (Available to all environments)**
   - `AWS_ACCESS_KEY_ID`: AWS access key with appropriate permissions
   - `AWS_SECRET_ACCESS_KEY`: AWS secret key
   - `TF_STATE_BUCKET`: S3 bucket name for Terraform state storage
   - `SLACK_WEBHOOK_URL`: Webhook URL for Slack notifications

2. **Environment-specific Secrets (Optional)**
   You can also create environment-specific secrets if you need different AWS credentials per environment:
   - `AWS_ACCESS_KEY_ID` (per environment)
   - `AWS_SECRET_ACCESS_KEY` (per environment)

### GitHub Variables

Add the following variables to each environment:

1. **dev Environment Variables**
   - `AWS_REGION`: ap-south-1
   - `MIN_REPLICAS`: 1
   - `MAX_REPLICAS`: 3
   - `DB_INSTANCE_CLASS`: db.t3.micro
   - `DB_ALLOCATED_STORAGE`: 20

2. **test Environment Variables**
   - `AWS_REGION`: ap-south-1
   - `MIN_REPLICAS`: 2
   - `MAX_REPLICAS`: 5
   - `DB_INSTANCE_CLASS`: db.t3.small
   - `DB_ALLOCATED_STORAGE`: 20

3. **prod Environment Variables**
   - `AWS_REGION`: ap-south-1
   - `MIN_REPLICAS`: 3
   - `MAX_REPLICAS`: 10
   - `DB_INSTANCE_CLASS`: db.t3.medium
   - `DB_ALLOCATED_STORAGE`: 50

4. **monitoring Environment Variables**
   - `AWS_REGION`: ap-south-1
   - `MIN_REPLICAS`: 1
   - `MAX_REPLICAS`: 2
   - `DB_INSTANCE_CLASS`: db.t3.small
   - `DB_ALLOCATED_STORAGE`: 20
   - `CONNECT_TO_LOWER_ENV`: true
   - `CONNECT_TO_HIGHER_ENV`: true

## Deployment Instructions

### Initial Infrastructure Deployment

1. **Lower Environment (Dev/Test)**
   ```bash
   # Deploy Dev Environment
   gh workflow run infra-deploy.yml -f action=apply -f environment=dev

   # Deploy Test Environment
   gh workflow run infra-deploy.yml -f action=apply -f environment=test
   ```

2. **Higher Environment (Prod)**
   ```bash
   gh workflow run infra-deploy.yml -f action=apply -f environment=prod
   ```

3. **Monitoring Environment**
   ```bash
   gh workflow run monitor-deploy.yml -f action=apply
   ```

### Application Deployment

Application deployment is handled automatically through GitHub Actions when code is pushed to the respective branches:

- **develop** branch → Development environment
- **staging** branch → Test environment
- **main** branch → Production environment

## Network Connectivity

The VPC peering connections allow resources in the Monitoring environment to communicate with resources in both the Lower and Higher environments. This enables centralized monitoring and logging for all environments.

## Security Considerations

1. **Network Isolation**: Production (Higher) environment is completely isolated from Dev/Test (Lower) environment.

2. **Access Control**: Use GitHub environment protection rules to control who can deploy to each environment.

3. **Credential Management**: Use environment-specific secrets for stricter control of AWS credentials.

4. **Monitoring**: The Monitoring environment has visibility into all environments for comprehensive observability.
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