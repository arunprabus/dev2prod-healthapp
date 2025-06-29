# 🏥 Health App Infrastructure Repository

## Production-Ready Infrastructure with Blue-Green Deployment

This repository contains the infrastructure code for the Health App platform. The application code has been moved to separate repositories to follow separation of concerns.

## Repository Structure

- `infra/`: Infrastructure as Code (IaC) using Terraform
  - `modules/`: Reusable Terraform modules
  - `environments/`: Environment-specific configurations
- `.github/workflows/`: CI/CD pipelines
  - `infra-deploy.yml`: Infrastructure deployment pipeline
  - `app-deploy.yml`: Application deployment pipeline (triggers deployments to infrastructure)

## Related Repositories

- [Health API](https://github.com/arunprabus/health-api): Backend API code
- [Health Frontend](https://github.com/arunprabus/health-dash): Frontend application code

## Infrastructure Deployment

The infrastructure code manages the following resources:

- VPC and networking components
- EKS clusters for different environments
- RDS database instances
- Deployment configurations via ArgoCD

## Deployment Strategy

### Infrastructure

The infrastructure is deployed using the GitHub Actions workflow in `.github/workflows/infra-deploy.yml`. This creates the base infrastructure for each environment (development, test, production).

### Applications

Application deployments are handled through the following process:

1. Code is pushed to the application repositories (HealthApi or HealthFrontend)
2. The `.github/workflows/app-deploy.yml` workflow is triggered
3. The workflow builds the application and pushes it to the container registry
4. ArgoCD detects the changes and deploys the application to the appropriate environment

### Environment Targeting

- **Development Environment**: Triggered by pushes to the `develop` branch
- **Test Environment**: Triggered by pushes to the `staging` branch
- **Production Environment**: Triggered by pushes to the `main` branch

## Getting Started

### Prerequisites

- AWS CLI configured with appropriate credentials
- Terraform CLI (v1.6.0 or later)
- kubectl

### Deploying Infrastructure

You can deploy the infrastructure using the GitHub Actions workflow or manually:

```bash
cd infra
terraform init \
  -backend-config="bucket=your-terraform-state-bucket" \
  -backend-config="key=health-app-dev.tfstate" \
  -backend-config="region=ap-south-1"
terraform apply -var-file="environments/dev.tfvars"
```

## Maintenance

The separation of application and infrastructure code allows for:

1. Independent scaling of infrastructure without affecting application code
2. Clearer responsibility boundaries
3. Simplified CI/CD pipelines
4. Better security and access control
> 🚀 Enterprise-grade multi-environment setup with EKS, RDS, and **Blue-Green deployment strategy**—perfect for learning production DevOps practices.

---

## 🧱 Network Architecture

```
┌───────────────────────────────────────────────────────────────────────┐
│                       AWS Region: ap-south-1                          │
├───────────────────────────────────────────────────────────────────────┤
│                                                                       │
│ ┌─────────────────────────────────────────────────────────────────┐   │
│ │                 LOWER NETWORK (10.0.0.0/16)                     │   │
│ │ ┌──────────────┐     ┌──────────────┐                           │   │
│ │ │  DEV ENV     │     │  TEST ENV    │                           │   │
│ │ │ EKS + RDS    │     │ EKS + RDS    │                           │   │
│ │ └──────────────┘     └──────────────┘                           │   │
│ └─────────────────────────────────────────────────────────────────┘   │
│                                                                       │
│ ┌─────────────────────────────────────────────────────────────────┐   │
│ │                HIGHER NETWORK (10.1.0.0/16)                     │   │
│ │ ┌──────────────┐                                                │   │
│ │ │  PROD ENV    │                                                │   │
│ │ │ EKS + RDS    │                                                │   │
│ │ └──────────────┘                                                │   │
│ └─────────────────────────────────────────────────────────────────┘   │
│                                                                       │
│ ┌─────────────────────────────────────────────────────────────────┐   │
│ │               MONITORING NETWORK (10.3.0.0/16)                  │   │
│ │ ┌───────────────────────────────────┐      VPC Peering          │   │
│ │ │  MONITORING ENV                   │◀─────Connection──────────▶│   │
│ │ │  EKS + Splunk + Prometheus        │                           │   │
│ │ └───────────────────────────────────┘                           │   │
│ └─────────────────────────────────────────────────────────────────┘   │
└───────────────────────────────────────────────────────────────────────┘
```

> 🔒 **Enhanced Architecture**: Complete network isolation between Production and Dev/Test environments with centralized monitoring that has visibility into all environments.

---

## 💰 Cost Comparison

### 🆓 Free Tier Setup (K3s)
| Resource | Quantity | Free Tier | Monthly Cost |
|----------|----------|-----------|-------------|
| EC2 t2.micro | 1 | 750 hrs | **$0** |
| RDS db.t3.micro | 1 | 750 hrs | **$0** |
| VPC + Networking | 1 | Unlimited | **$0** |
| **Total** | | | **$0/month** |

### 💰 EKS Setup (Production)
| Resource | Quantity | Free Tier | Monthly Cost |
|----------|----------|-----------|-------------|
| EKS Control Plane | 1 | ❌ Not Free | **$73** |
| EC2 t2.micro | 1 | 750 hrs | $0 |
| RDS db.t3.micro | 1 | 750 hrs | $0 |
| **Total** | | | **$73/month** |

### 📈 Multi-Environment EKS
| Environment | EKS Cost | EC2 Cost | RDS Cost | Total |
|-------------|----------|----------|----------|-------|
| Dev | $73 | $0 | $0 | $73 |
| QA | $73 | $0 | $0 | $73 |
| Prod | $73 | $0 | $0 | $73 |
| **Total** | **$219** | **$0** | **$0** | **$219/month** |

---

## 🚀 Quick Start

### 🆓 Option 1: Free Tier Setup (Recommended for Learning)
```bash
# 1. Clone repository
git clone https://github.com/your-organization/health-app-infra.git
cd health-app-infra/infra

# 2. Edit SSH key in envs/free-tier/variables.tf
# 3. Deploy 100% FREE Kubernetes cluster
make init-free && make apply-free

# 4. Connect to your cluster
ssh -i ~/.ssh/your-key ubuntu@<MASTER_IP>

# Cost: $0/month (uses K3s on EC2 t2.micro + RDS db.t3.micro)
```

### 💰 Option 2: Production EKS Setup (~$73/month)
```bash
# Prerequisites: AWS CLI, GitHub secrets configured

# 1. Configure GitHub Environments & Variables
# 2. Configure GitHub Secrets (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY)
# 3. Deploy via GitHub Actions → Deploy to EKS → Run workflow

# Cost: $73/month per environment (EKS control plane)
```

## ⚙️ Configuration Management

### **Environment Variables (Configurable)**
| Variable | Default | Purpose |
|----------|---------|----------|
| `AWS_REGION` | `ap-south-1` | Deployment region |
| `EKS_CLUSTER_NAME` | `health-app-cluster` | Cluster base name |
| `CONTAINER_REGISTRY` | `ghcr.io` | Container registry |
| `REGISTRY_NAMESPACE` | `your-organization` | Registry namespace |
| `TERRAFORM_VERSION` | `1.6.0` | Terraform version |
| `KUBECTL_TIMEOUT` | `300s` | K8s operation timeout |

### **Multi-Environment Support**
- **Dev**: Fast deployments, shorter timeouts
- **Test**: Balanced configuration for testing
- **Prod**: Conservative settings, longer timeouts

### **Multi-Region Ready**
```yaml
# Asia Pacific
AWS_REGION: "ap-south-1"

# US East
AWS_REGION: "us-east-1"

# Europe
AWS_REGION: "eu-west-1"
```

## 🏢 Enterprise Benefits

### **Multi-Customer Deployments**
- **Isolated configurations** per customer
- **Separate AWS accounts** and regions
- **Custom branding** and domain names
- **Independent scaling** policies

### **Regional Compliance**
- **Data residency** requirements
- **GDPR compliance** in EU regions
- **Local regulations** adherence
- **Disaster recovery** across regions

### **Environment Isolation**
- **Different settings** per environment
- **Resource sizing** optimization
- **Security policies** per env
- **Cost allocation** tracking

### **Zero Code Changes**
- **Configuration-driven** deployments
- **Template reusability** across projects
- **Rapid environment** provisioning
- **Consistent deployments** everywhere

### **Centralized Configuration**
- **GitHub variables** management
- **Environment-specific** secrets
- **Version-controlled** configurations
- **Audit trail** for changes

## 🚀 Usage Examples

### **Global Company Setup**
```yaml
# US Production
AWS_REGION: "us-east-1"
EKS_CLUSTER_NAME: "health-app-us-prod"
CONTAINER_REGISTRY: "your-company.dkr.ecr.us-east-1.amazonaws.com"
REGISTRY_NAMESPACE: "production"
MIN_REPLICAS: "3"
MAX_REPLICAS: "20"

# EU Production  
AWS_REGION: "eu-west-1"
EKS_CLUSTER_NAME: "health-app-eu-prod"
CONTAINER_REGISTRY: "your-company.dkr.ecr.eu-west-1.amazonaws.com"
REGISTRY_NAMESPACE: "production-eu"
MIN_REPLICAS: "2"
MAX_REPLICAS: "15"

# APAC Production
AWS_REGION: "ap-south-1" 
EKS_CLUSTER_NAME: "health-app-apac-prod"
CONTAINER_REGISTRY: "your-company.dkr.ecr.ap-south-1.amazonaws.com"
REGISTRY_NAMESPACE: "production-apac"
MIN_REPLICAS: "2"
MAX_REPLICAS: "10"
```

### **Multi-Tenant SaaS Setup**
```yaml
# Customer A (Enterprise)
REGISTRY_NAMESPACE: "customer-a"
EKS_CLUSTER_NAME: "customer-a-cluster"
AWS_REGION: "us-west-2"
MIN_REPLICAS: "5"
MAX_REPLICAS: "50"
KUBECTL_TIMEOUT: "600s"
CLEANUP_DELAY: "120"

# Customer B (Startup)
REGISTRY_NAMESPACE: "customer-b"  
EKS_CLUSTER_NAME: "customer-b-cluster"
AWS_REGION: "us-east-1"
MIN_REPLICAS: "2"
MAX_REPLICAS: "10"
KUBECTL_TIMEOUT: "300s"
CLEANUP_DELAY: "30"
```

### **Development vs Production**
```yaml
# Development Environment
AWS_REGION: "ap-south-1"
EKS_CLUSTER_NAME: "health-app-dev"
CONTAINER_REGISTRY: "ghcr.io"
MIN_REPLICAS: "1"
MAX_REPLICAS: "3"
KUBECTL_TIMEOUT: "180s"
CLEANUP_DELAY: "10"
LB_WAIT_TIME: "30"

# Production Environment
AWS_REGION: "us-east-1"
EKS_CLUSTER_NAME: "health-app-prod"
CONTAINER_REGISTRY: "your-company.dkr.ecr.us-east-1.amazonaws.com"
MIN_REPLICAS: "3"
MAX_REPLICAS: "20"
KUBECTL_TIMEOUT: "600s"
CLEANUP_DELAY: "120"
LB_WAIT_TIME: "180"
```

---

## 🔄 Blue-Green Deployment Strategy

### How It Works
1. **Blue Environment**: Current production version
2. **Green Environment**: New version deployment
3. **Traffic Switch**: Instant cutover with zero downtime
4. **Auto Rollback**: Automatic revert on failure

### Deployment Flow
```
Blue (Live) ──┐
              ├─→ Load Balancer ──→ Users
Green (New) ──┘
```

## 🌐 Application Access

| Environment | EKS Cluster | Frontend | Backend | Status |
|-------------|-------------|----------|---------|--------|
| Dev | health-app-cluster-dev | LoadBalancer | LoadBalancer | Active |
| Test | health-app-cluster-test | LoadBalancer | LoadBalancer | Active |
| Prod | health-app-cluster-prod | LoadBalancer | LoadBalancer | Blue-Green |

---

## 🛠️ Deployment Commands

### GitHub Actions Workflows
| Workflow | Trigger | Description |
|----------|---------|-------------|
| `Deploy to EKS` | Manual | Blue-green deployment with rollback |
| `Manual Rollback` | Manual | Instant rollback to previous version |
| `Infrastructure Deploy` | Manual | Terraform infrastructure setup |
| `Infrastructure Shutdown` | Manual | Cost-saving resource cleanup |

### Manual Operations
```bash
# Check deployment status
kubectl get deployments
kubectl get services

# View current active color
kubectl get service health-api-service -o jsonpath='{.spec.selector.color}'
```

## 🚨 Rollback Procedures

### 1. GitHub Actions Rollback (Recommended)
1. Go to **Actions** → **Manual Rollback**
2. Select environment (dev/test/prod)
3. Click **Run workflow**

### 2. Emergency Production Rollback (Fastest)
```bash
aws eks update-kubeconfig --region ap-south-1 --name health-app-cluster-prod
kubectl patch service health-api-service -p '{"spec":{"selector":{"color":"blue"}}}'
kubectl patch service frontend-service -p '{"spec":{"selector":{"color":"blue"}}}'
```

### 3. Script-based Rollback
```bash
chmod +x scripts/rollback.sh
./scripts/rollback.sh prod    # Production
./scripts/rollback.sh test    # Test
./scripts/rollback.sh dev     # Development
```

### 4. Environment-Specific Commands
```bash
# Dev Environment
aws eks update-kubeconfig --region ap-south-1 --name health-app-cluster-dev
kubectl patch service health-api-service -p '{"spec":{"selector":{"color":"blue"}}}'

# Test Environment
aws eks update-kubeconfig --region ap-south-1 --name health-app-cluster-test
kubectl patch service health-api-service -p '{"spec":{"selector":{"color":"blue"}}}'

# Production Environment
aws eks update-kubeconfig --region ap-south-1 --name health-app-cluster-prod
kubectl patch service health-api-service -p '{"spec":{"selector":{"color":"blue"}}}'
```

> ⚡ **Rollback is instant** - switches traffic between blue/green versions with zero downtime

---

## 💸 Cost Control

```bash
make stop-all     # Stop all EC2 (save costs)
make start-all    # Restart EC2 instances
make destroy-all  # Tear everything down
```

---

## 🔒 Security & Isolation

- ✅ Two distinct VPCs (Lower: Dev/Test, Higher: Prod)
- ✅ Complete isolation—no cross-VPC traffic
- ✅ SSH key-based login
- ✅ Public subnets only (no NAT Gateway)

---

## 📁 Repository Structure

```
├── .github/workflows/     # CI/CD pipelines
│   ├── deploy.yml        # Blue-green deployment
│   ├── infra-deploy.yml  # Infrastructure setup
│   └── infra-shutdown.yml # Cost management
├── infra/                # Terraform infrastructure
│   ├── modules/          # Reusable modules
│   │   ├── eks/          # EKS module ($73/month)
│   │   ├── k3s/          # K3s module (FREE)
│   │   ├── vpc/          # VPC module
│   │   └── rds/          # RDS module
│   ├── envs/             # Environment-specific configs
│   │   ├── dev/          # EKS dev environment
│   │   ├── qa/           # EKS qa environment
│   │   ├── prod/         # EKS prod environment
│   │   └── free-tier/    # K3s FREE environment
│   └── backend-configs/  # Terraform state configs
├── k8s/                  # Kubernetes manifests
│   ├── health-api-deployment.yaml
│   ├── frontend-deployment.yaml
│   ├── hpa.yaml             # Horizontal Pod Autoscaler
│   ├── vpa.yaml             # Vertical Pod Autoscaler
│   ├── cluster-autoscaler.yaml  # Cluster scaling
│   ├── advanced-hpa.yaml    # Custom metrics scaling
│   ├── rbac.yaml            # Security policies
│   ├── monitoring.yaml      # Prometheus setup
│   ├── logging.yaml         # Centralized logging
│   ├── canary-rollout.yaml  # Advanced deployment
│   └── argocd-app.yaml      # GitOps setup
└── README.md
```

## 🔧 Advanced Deployment Options

### 1. Canary Deployment
```bash
# Install Argo Rollouts
kubectl create namespace argo-rollouts
kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml

# Deploy canary
kubectl apply -f k8s/canary-rollout.yaml
```

### 2. GitOps with ArgoCD
```bash
# Install ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Deploy application
kubectl apply -f k8s/argocd-app.yaml
```

## 🏢 Enterprise Features

### Security & Compliance
- 🔒 **RBAC**: Role-based access control
- 🛡️ **Pod Security**: Non-root containers, read-only filesystem
- 🔍 **Security Scanning**: Trivy vulnerability scanning
- 🌐 **Network Policies**: Micro-segmentation

### Monitoring & Observability
- 📊 **Prometheus**: Metrics collection
- 🚨 **Alerting**: Automated incident detection
- 📄 **Centralized Logging**: Fluent Bit + CloudWatch
- 💰 **Cost Monitoring**: Weekly spend alerts

### Auto-Scaling & Performance
- 📈 **Horizontal Scaling (HPA)**: 2-10 pods based on CPU/memory
- 📉 **Vertical Scaling (VPA)**: Auto-adjusts pod resources
- 🏢 **Cluster Scaling**: Auto-adds/removes nodes
- 📊 **Advanced Metrics**: Custom scaling triggers
- 🧪 **Load Testing**: Automated performance validation
- 🔄 **Blue-Green**: Zero-downtime deployments
- 💾 **Backup**: Automated DynamoDB backups

## 🧪 Learning Highlights

### 🆓 Free Tier Learning (K3s Setup)
- 🔄 **Kubernetes Fundamentals**: Pods, services, deployments
- 💻 **EC2 Management**: SSH, user-data, security groups
- 🗾 **Database Integration**: RDS connection from K3s
- 🔐 **Networking**: VPC, subnets, security groups
- 🛠️ **Infrastructure as Code**: Terraform modules
- 💰 **Cost Optimization**: 100% free tier usage

### 💼 Production Learning (EKS Setup)
- 🔄 **Blue-Green Deployment**: Zero-downtime deployments
- ⚙️ **EKS Management**: Production Kubernetes
- 🗄️ **DynamoDB + S3**: Serverless data layer
- 🔁 **Multi-environment**: Dev/Test/Prod isolation
- 🔐 **Security**: IAM roles, secrets management
- 📊 **Monitoring**: Health checks, rollback automation
- 🚀 **CI/CD**: GitHub Actions automation

## 🎯 Deployment & Scaling Strategies

### Deployment Strategies
| Strategy | Downtime | Risk | Complexity | Rollback Time | Use Case |
|----------|----------|------|------------|---------------|----------|
| Rolling | Minimal | Medium | Low | 2-5 min | Development |
| Blue-Green | Zero | Low | Medium | **Instant** | **Current Setup** |
| Canary | Zero | Very Low | High | Instant | Production |
| A/B Testing | Zero | Low | High | Instant | Feature testing |

### Auto-Scaling Strategies
| Type | Scope | Trigger | Response Time | Cost Impact |
|------|-------|---------|---------------|-------------|
| **HPA** | Pod replicas | CPU/Memory/Custom | 30-60s | Medium |
| **VPA** | Pod resources | Resource usage | 2-5 min | Low |
| **Cluster** | Node count | Pod scheduling | 2-3 min | High |
| **Predictive** | All levels | ML forecasting | Proactive | Optimized |

## 📈 Auto-Scaling Architecture

### 3-Tier Scaling Strategy
```
📊 Load Increases
    ↓
🔄 HPA: Scales pods (2→10)
    ↓
📉 VPA: Adjusts resources per pod
    ↓
🏢 Cluster: Adds/removes nodes
    ↓
⚡ Full auto-scaling achieved!
```

### Horizontal Pod Autoscaler (HPA)
- **Health API**: 2-10 replicas
- **Frontend**: 2-5 replicas
- **Triggers**: CPU > 70%, Memory > 80%
- **Advanced**: Custom metrics (RPS, queue length)

### Vertical Pod Autoscaler (VPA)
- **Auto-adjusts**: CPU/Memory requests & limits
- **Health API**: 100m-1000m CPU, 128Mi-1Gi memory
- **Frontend**: 50m-500m CPU, 64Mi-512Mi memory

### Cluster Autoscaler
- **Node scaling**: Adds EC2 instances when needed
- **Cost optimization**: Removes unused nodes
- **Multi-AZ**: Distributes across availability zones

## 🔍 Monitoring & Verification

### Auto-Scaling Status
```bash
# Monitor HPA status
kubectl get hpa -w

# Check VPA recommendations
kubectl get vpa -w

# View resource usage
kubectl top pods
kubectl top nodes

# Scaling events
kubectl get events --field-selector reason=ScalingReplicaSet
```

### Manual Scaling (if needed)
```bash
# Manual horizontal scaling
kubectl scale deployment health-api --replicas=5

# Check current scaling status
kubectl describe hpa health-api-hpa
kubectl describe vpa health-api-vpa
```

### Check Current Status
```bash
# View active deployment color
kubectl get service health-api-service -o jsonpath='{.spec.selector.color}'

# List all deployments
kubectl get deployments -l app=health-api

# Check service health
kubectl get services
kubectl get pods -l app=health-api
```

### Troubleshooting
```bash
# View deployment logs
kubectl logs -l app=health-api,color=green

# Check pod status
kubectl describe pods -l app=health-api

# View recent events
kubectl get events --sort-by=.metadata.creationTimestamp
```

---

## 📄 Complete Variables & Secrets Reference

### **Repository Variables (GitHub Settings → Variables)**

#### **Core Configuration**
```yaml
AWS_REGION: "ap-south-1"                    # AWS deployment region
EKS_CLUSTER_NAME: "health-app-cluster"       # Base cluster name
CONTAINER_REGISTRY: "ghcr.io"               # Container registry URL
REGISTRY_NAMESPACE: "your-username"          # Registry namespace
```

#### **Tool Versions**
```yaml
TERRAFORM_VERSION: "1.6.0"                  # Terraform version
KUBECTL_VERSION: "latest"                   # kubectl version
```

#### **Deployment Timeouts**
```yaml
KUBECTL_TIMEOUT: "300s"                     # Kubernetes operations timeout
CLEANUP_DELAY: "30"                         # Seconds before cleanup
LB_WAIT_TIME: "60"                          # Load balancer wait time
HEALTH_CHECK_RETRIES: "5"                   # Health check retry count
```

#### **Auto-Scaling Configuration**
```yaml
MIN_REPLICAS: "2"                           # Minimum pod replicas
MAX_REPLICAS: "10"                          # Maximum pod replicas
```

### **Repository Secrets (GitHub Settings → Secrets)**

#### **AWS Credentials**
```yaml
AWS_ACCESS_KEY_ID: "AKIA..."                # AWS access key
AWS_SECRET_ACCESS_KEY: "xyz123..."          # AWS secret key
```

#### **Notifications**
```yaml
SLACK_WEBHOOK_URL: "https://hooks.slack.com/..."  # Slack notifications
```

#### **Optional: Environment-Specific Secrets**
```yaml
# Development
AWS_ACCESS_KEY_ID_DEV: "AKIA..."            # Dev AWS credentials
AWS_SECRET_ACCESS_KEY_DEV: "xyz123..."

# Production
AWS_ACCESS_KEY_ID_PROD: "AKIA..."           # Prod AWS credentials
AWS_SECRET_ACCESS_KEY_PROD: "xyz123..."
```

### **Environment-Specific Variables**

#### **Development Environment**
```yaml
AWS_REGION: "ap-south-1"
EKS_CLUSTER_NAME: "health-app-dev"
CONTAINER_REGISTRY: "ghcr.io"
REGISTRY_NAMESPACE: "dev-team"
MIN_REPLICAS: "1"
MAX_REPLICAS: "3"
KUBECTL_TIMEOUT: "180s"
CLEANUP_DELAY: "10"
LB_WAIT_TIME: "30"
```

#### **Test Environment**
```yaml
AWS_REGION: "ap-south-1"
EKS_CLUSTER_NAME: "health-app-test"
CONTAINER_REGISTRY: "ghcr.io"
REGISTRY_NAMESPACE: "test-team"
MIN_REPLICAS: "2"
MAX_REPLICAS: "5"
KUBECTL_TIMEOUT: "240s"
CLEANUP_DELAY: "20"
LB_WAIT_TIME: "45"
```

#### **Production Environment**
```yaml
AWS_REGION: "us-east-1"
EKS_CLUSTER_NAME: "health-app-prod"
CONTAINER_REGISTRY: "your-company.dkr.ecr.us-east-1.amazonaws.com"
REGISTRY_NAMESPACE: "production"
MIN_REPLICAS: "3"
MAX_REPLICAS: "20"
KUBECTL_TIMEOUT: "600s"
CLEANUP_DELAY: "120"
LB_WAIT_TIME: "180"
```

### **Sample Multi-Region Configuration**

#### **US Region (Primary)**
```yaml
AWS_REGION: "us-east-1"
EKS_CLUSTER_NAME: "health-app-us"
CONTAINER_REGISTRY: "123456789.dkr.ecr.us-east-1.amazonaws.com"
REGISTRY_NAMESPACE: "us-production"
```

#### **EU Region (GDPR Compliance)**
```yaml
AWS_REGION: "eu-west-1"
EKS_CLUSTER_NAME: "health-app-eu"
CONTAINER_REGISTRY: "123456789.dkr.ecr.eu-west-1.amazonaws.com"
REGISTRY_NAMESPACE: "eu-production"
```

#### **APAC Region (Local Performance)**
```yaml
AWS_REGION: "ap-south-1"
EKS_CLUSTER_NAME: "health-app-apac"
CONTAINER_REGISTRY: "123456789.dkr.ecr.ap-south-1.amazonaws.com"
REGISTRY_NAMESPACE: "apac-production"
```

### **Quick Setup Commands**

```bash
# Set repository variables using GitHub CLI
gh variable set AWS_REGION --body "ap-south-1"
gh variable set EKS_CLUSTER_NAME --body "health-app-cluster"
gh variable set CONTAINER_REGISTRY --body "ghcr.io"
gh variable set REGISTRY_NAMESPACE --body "your-organization"
gh variable set MIN_REPLICAS --body "2"
gh variable set MAX_REPLICAS --body "10"

# Set repository secrets
gh secret set AWS_ACCESS_KEY_ID --body "AKIA..."
gh secret set AWS_SECRET_ACCESS_KEY --body "xyz123..."
gh secret set SLACK_WEBHOOK_URL --body "https://hooks.slack.com/..."

# Set environment-specific variables
gh variable set AWS_REGION --env dev --body "ap-south-1"
gh variable set AWS_REGION --env prod --body "us-east-1"
```

---

**🎓 Perfect for mastering enterprise-grade deployment strategies!**
