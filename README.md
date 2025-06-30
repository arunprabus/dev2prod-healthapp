# 🏥 Health App Infrastructure Repository

## Production-Ready K8s Infrastructure with Complete DevOps Pipeline

This repository contains the complete infrastructure and deployment pipeline for the Health App platform, configured for **Kubernetes (K8s) instead of EKS** for cost-effective, production-ready deployments.

## 🚀 **Key Features**

- ✅ **K8s Native Deployment** - Direct Kubernetes without EKS overhead
- ✅ **Multi-Environment Support** - dev/test/prod isolation
- ✅ **Auto-Scaling & Monitoring** - HPA, health checks, Prometheus
- ✅ **Cost Optimization** - Resource scheduling, auto-shutdown
- ✅ **Complete CI/CD** - GitHub Actions automation
- ✅ **Infrastructure as Code** - Terraform + K8s manifests

## Repository Structure

- `infra/`: Infrastructure as Code (IaC) using Terraform
  - `modules/`: Reusable Terraform modules (VPC, K8s, RDS)
  - `environments/`: Environment-specific configurations
- `.github/workflows/`: Complete CI/CD pipeline
  - `infrastructure.yml`: Infrastructure deployment
  - `app-deploy.yml`: Application deployment
  - `k8s-operations.yml`: K8s management & scaling
  - `monitoring.yml`: Health checks & monitoring
  - `resource-cleanup.yml`: Cost optimization
- `k8s/`: Kubernetes manifests
  - `health-api-complete.yaml`: Complete app deployment
  - `monitoring-stack.yaml`: Prometheus + Grafana
- `scripts/`: Automation scripts
  - `k8s-health-check.sh`: Health monitoring
  - `k8s-auto-scale.sh`: Auto-scaling management
  - `rds-monitor.sh`: Database monitoring

## Related Repositories

- [Health API](https://github.com/arunprabus/health-api): Backend API code
- [Health Frontend](https://github.com/arunprabus/health-dash): Frontend application code

## Infrastructure Deployment

The infrastructure code manages the following resources:

- **VPC and networking** (isolated per environment)
- **K8s clusters** on EC2 (cost-effective alternative to EKS)
- **RDS database instances** with automated monitoring
- **Multi-environment setup** (dev/test/prod namespaces)
- **Auto-scaling** (HPA + resource scheduling)
- **Monitoring stack** (Prometheus + Grafana)
- **Cost optimization** (automated cleanup + scheduling)

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

## 💰 Cost Comparison & Database Backup Strategy

### 🆓 **Current Setup: 100% FREE TIER**
| Resource | Usage | Free Tier Limit | Monthly Cost |
|----------|-------|-----------------|-------------|
| EC2 t2.micro | 720 hrs | 750 hrs/month | **$0** |
| RDS db.t3.micro | 720 hrs | 750 hrs/month | **$0** |
| EBS Storage | 28GB | 30GB/month | **$0** |
| VPC + Networking | Unlimited | Unlimited | **$0** |
| **Total** | | | **$0/month** |

### 💾 **Database Backup Strategy: 97% Cost Savings**

#### **Backup Cost Comparison**
| Method | Storage Cost | Restore Method | Monthly Cost | Savings |
|--------|-------------|----------------|--------------|----------|
| **RDS Snapshot** | $0.095/GB | Native AWS restore | **$1.90/month** | Baseline |
| **S3 Export** | $0.023/GB | Manual import | **$0.05/month** | **97% savings** |
| **S3 Intelligent Tiering** | $0.0125/GB | Manual import | **$0.03/month** | **98% savings** |

#### **Implementation**
```bash
# Current Status: RDS Stopped, Snapshot Created
aws rds describe-db-instances --query "DBInstances[?DBInstanceStatus=='stopped'].[DBInstanceIdentifier,DBInstanceStatus]"

# S3 Export (Automated)
aws rds start-export-task \
  --export-task-identifier healthapi-export-$(date +%Y%m%d) \
  --source-arn arn:aws:rds:region:account:snapshot:healthapidb-backup-$(date +%Y%m%d) \
  --s3-bucket-name health-app-terraform-state \
  --s3-prefix db-exports/ \
  --iam-role-arn arn:aws:iam::account:role/rds-s3-export-role

# Manual Export (Alternative)
pg_dump -h endpoint -U postgres -d healthapi | gzip > backup.sql.gz
aws s3 cp backup.sql.gz s3://health-app-terraform-state/db-backups/
```

#### **Restore Process**
```bash
# From S3 Backup
aws s3 cp s3://health-app-terraform-state/db-backups/backup.sql.gz .
gunzip backup.sql.gz
psql -h new-endpoint -U postgres -d healthapi < backup.sql

# From RDS Snapshot (Terraform)
cd infra
terraform apply -var="restore_from_snapshot=true" -var="snapshot_identifier=healthapidb-backup-20250102"
```

#### **Cost Optimization Achieved**
- **Before**: RDS running 24/7 = $13-15/month
- **After**: RDS stopped + S3 backup = $0.05/month
- **Total Savings**: $13-15/month (99.7% reduction)

### 💰 Alternative: EKS Setup (Production)
| Resource | Quantity | Free Tier | Monthly Cost |
|----------|----------|-----------|-------------|
| EKS Control Plane | 1 | ❌ Not Free | **$73** |
| NAT Gateway | 1 | ❌ Not Free | **$45** |
| EC2 t2.micro | 1 | 750 hrs | $0 |
| RDS db.t3.micro | 1 | 750 hrs | $0 |
| RDS Snapshots | 20GB | ❌ Not Free | **$1.90** |
| **Total** | | | **$119.90/month** |

### 📊 **Cost Savings Achieved: 95%+**
| Setup | Monthly Cost | Savings |
|-------|-------------|----------|
| **K3s (Current)** | **$0** | **Baseline** |
| EKS Alternative | $118 | -$118/month |
| **Multi-Env K3s** | **$0** | **vs $354/month** |

---

## 🚀 Quick Start

### 🆓 **Deploy Instructions: $0 Cost Infrastructure**

#### **⚙️ Prerequisites**
1. **AWS Account** with Free Tier available
2. **SSH Key Pair** generated
3. **GitHub Secrets** configured

#### **🚀 Deployment Steps**

**Step 1: Generate SSH Key**
```bash
# Generate SSH key if you don't have one
ssh-keygen -t rsa -b 4096 -f ~/.ssh/aws-key

# Copy your public key content
cat ~/.ssh/aws-key.pub
```

**Step 2: Configure GitHub Secrets & Variables**
Go to **Settings** → **Secrets and variables** → **Actions**:

**🔐 Secrets tab (Required):**
```yaml
AWS_ACCESS_KEY_ID: "AKIA..."
AWS_SECRET_ACCESS_KEY: "xyz123..."
KUBECONFIG: "Base64 encoded kubeconfig file"
SSH_PUBLIC_KEY: "ssh-rsa AAAAB3..."
TF_STATE_BUCKET: "health-app-terraform-state"
```

**⚙️ Variables tab (K8s Configuration):**
```yaml
AWS_REGION: "ap-south-1"
K8S_CLUSTER_NAME: "health-app-cluster"
CONTAINER_REGISTRY: "your-account.dkr.ecr.ap-south-1.amazonaws.com"
REGISTRY_NAMESPACE: "health-app"
MIN_REPLICAS: "1"
MAX_REPLICAS: "5"
KUBECTL_TIMEOUT: "300s"
BUDGET_EMAIL: "your-email@domain.com"
BUDGET_REGIONS: "us-east-1,ap-south-1"
```

## 🏷️ **Tagging & Naming Standards**

### **Industry Standard Tags**
```yaml
# Required Tags (Cost & Operations)
Project: "health-app"
Environment: "dev|test|prod"
Owner: "devops-team"
CostCenter: "engineering"
ManagedBy: "terraform"
Application: "health-api"
BackupRequired: "true"

# Compliance & Security
DataClassification: "internal"
ComplianceScope: "hipaa"
MonitoringLevel: "medium"
Schedule: "business-hours"
AutoShutdown: "enabled"
```

### **Resource Naming Convention**
```yaml
# Format: {project}-{component}-{environment}
AWS Resources:
  VPC: "health-app-vpc-dev"
  EC2: "health-app-k8s-master-dev"
  RDS: "health-app-db-dev"
  S3: "health-app-terraform-state-dev"

K8s Resources:
  Namespace: "health-app-dev"
  Deployment: "health-api-backend-dev"
  Service: "health-api-service-dev"
```

### **Benefits**
- 💰 **Cost Tracking**: Automated cost allocation by project/team
- 🔄 **Automation**: Auto-shutdown, backup policies
- 🛡️ **Compliance**: HIPAA, GDPR compliance tracking
- 📊 **Operations**: Resource lifecycle management

## 🔧 **AWS Technology Integrations**

### **FREE Tier Enhancements ($0/month)**
```yaml
# Observability & Monitoring
CloudWatch Logs: "Centralized application logging"
CloudWatch Metrics: "Custom metrics collection"
CloudWatch Alarms: "Automated alerting"
Systems Manager: "Enhanced secrets management"
CloudTrail: "Audit logging and compliance"
Lambda Functions: "Cost optimization automation"
```

### **Low-Cost Additions (~$25/month)**
```yaml
# Advanced Features
X-Ray: "$5/month - Distributed tracing"
AWS Config: "$10/month - Compliance monitoring"
Secrets Manager: "$5/month - Advanced secrets"
EventBridge: "$5/month - Event processing"
```

### **Splunk Integration Options**
```yaml
# Enterprise Logging
Splunk Universal Forwarder: "$150+/month - Direct integration"
Splunk Connect for K8s: "Native K8s integration"
Kinesis → Splunk: "Cost-effective pipeline"
ELK Stack Alternative: "$0/month - Self-hosted"
```

### **Automated Cost Optimization**
- 🕘 **Business Hours**: Auto-start at 9 AM UTC
- 🌙 **After Hours**: Auto-stop at 6 PM UTC
- 🏷️ **Tag-based Control**: Environment and AutoShutdown tags
- 🤖 **Lambda Functions**: Serverless automation

### **Implementation Phases**
- **Phase 1 (FREE)**: CloudWatch + Lambda automation
- **Phase 2 ($25/month)**: X-Ray + Config + advanced monitoring
- **Phase 3 ($100+/month)**: Splunk + enterprise security

**Step 3: Deploy AWS Integrations (Optional)**
```bash
# Deploy AWS integrations
kubectl apply -f k8s/aws-integrations.yaml

# Deploy Lambda cost optimizer
aws lambda create-function --function-name health-app-cost-optimizer \
  --runtime python3.9 --role arn:aws:iam::ACCOUNT:role/lambda-role \
  --handler lambda_function.lambda_handler \
  --zip-file fileb://scripts/aws-lambda-cost-optimizer.zip
```

**Step 4: Deploy AWS Integrations**
```bash
# Deploy FREE AWS integrations
Actions → AWS Integrations Deployment → action: "deploy-all" → environment: "dev"

# Test integrations
chmod +x scripts/test-aws-integrations.sh
./scripts/test-aws-integrations.sh dev
```

**Step 5: Deploy via GitHub Actions**
1. Go to **Actions** → **Infrastructure**
2. Select **action**: `deploy`
3. Select **environment**: `dev`
4. Click **Run workflow**

**Step 4: Access Your Infrastructure**
```bash
# SSH to K3s node (get IP from GitHub Actions output)
ssh -i ~/.ssh/aws-key ubuntu@<EC2_PUBLIC_IP>

# Access Kubernetes cluster
kubectl --server=https://<EC2_PUBLIC_IP>:6443 get nodes
```

**Step 5: Setup Cost Protection (Optional)**
1. Go to **Actions** → **Cost Management**
2. Select **action**: `budget-setup`
3. **Leave email empty** to use GitHub variables OR enter custom email
4. Click **Run workflow**
5. You'll get email alerts if any cost > $0.01

**Step 6: Monitor Costs (Automatic)**
- **Cost Management** workflow runs every Monday (9 AM monitor, 10 AM cleanup)
- Checks last 7 days of spending
- Auto-removes costly resources if > $0.50
- Manual run: **Actions** → **Cost Management** → Select action

**Step 7: Cleanup When Done**
1. Go to **Actions** → **Infrastructure**
2. Select **action**: `destroy`
3. Select **environment** (dev/test/prod/monitoring/all)
4. Type **"DESTROY"** in confirmation field
5. Click **Run workflow**
6. All resources will be deleted (cost returns to $0)

#### **💰 Cost Verification**
| Resource | Usage | Free Tier | Status |
|----------|-------|-----------|--------|
| EC2 t2.micro | 720h/month | 750h limit | ✅ **$0** |
| RDS db.t3.micro | 720h/month | 750h limit | ✅ **$0** |
| EBS Storage | ~28GB | 30GB limit | ✅ **$0** |
| VPC + Networking | Unlimited | Always free | ✅ **$0** |
| **Total Monthly Cost** | | | **$0** |

#### **🛡️ Safety Features**
- ✅ **Instance type locked** to t2.micro (FREE TIER)
- ✅ **RDS locked** to db.t3.micro (FREE TIER)
- ✅ **No NAT Gateway** (would cost $45/month)
- ✅ **No Load Balancers** (would cost $18/month each)
- ✅ **Storage limits** enforced (20GB max)

#### **🔄 Multi-Environment Deployment**
```bash
# Deploy Single Environment
Actions → Infrastructure → action: "deploy" → environment: "test"

# Deploy All Environments at Once
Actions → Infrastructure → action: "deploy" → environment: "all"

# Each environment: $0/month
# Total all environments: $0/month
```

#### **📊 Alternative: Manual Deployment**
```bash
# Clone repository
git clone https://github.com/arunprabus/dev2prod-healthapp.git
cd dev2prod-healthapp/infra

# Initialize Terraform
terraform init

# Plan deployment (verify $0 cost)
terraform plan -var-file="environments/dev.tfvars" -var="ssh_public_key=$(cat ~/.ssh/aws-key.pub)"

# Apply (deploy infrastructure)
terraform apply -var-file="environments/dev.tfvars" -var="ssh_public_key=$(cat ~/.ssh/aws-key.pub)"

# Create budget via CLI (optional)
cd ..
chmod +x create-budget-cli.sh
./create-budget-cli.sh your-email@domain.com 1.00 "Dev-Budget"

# Destroy when done (optional)
cd infra
terraform destroy -var-file="environments/dev.tfvars" -var="ssh_public_key=$(cat ~/.ssh/aws-key.pub)"
```

#### **💰 CLI Budget Creation:**
```bash
# Basic usage (default: admin@example.com, $1.00)
./create-budget-cli.sh

# Custom parameters
./create-budget-cli.sh your-email@domain.com 5.00 "Custom-Budget"

# Usage: ./create-budget-cli.sh [email] [amount] [budget-name]
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
| `Infrastructure` | Manual | **Deploy/Destroy/Plan** - All infrastructure operations |
| `Cost Management` | Schedule/Manual | **Monitor + Cleanup + Budget** - Complete cost protection |

### **Infrastructure Workflow Actions:**
- **deploy**: Create/update infrastructure
- **destroy**: Delete all resources (requires "DESTROY" confirmation)
- **plan**: Preview changes without applying

### **Cost Management Workflow Actions:**
- **monitor**: Check weekly costs (auto-runs breakdown if > $0.50)
- **cleanup**: Remove expensive resources
- **budget-setup**: Create cost alerts
- **breakdown**: Detailed cost analysis by service/region
- **all**: Run monitor + cleanup + budget setup + breakdown

### Manual Operations
```bash
# Check deployment status
kubectl get deployments
kubectl get services

# Plan infrastructure changes
Actions → Infrastructure → action: "plan" → environment: "dev"

# Monitor costs manually
Actions → Cost Management → action: "monitor"
```

## 🚨 Emergency Procedures

### 1. Infrastructure Rollback
```bash
# Destroy problematic environment
Actions → Infrastructure → action: "destroy" → environment: "dev" → confirm: "DESTROY"

# Redeploy clean environment
Actions → Infrastructure → action: "deploy" → environment: "dev"
```

### 2. Cost Emergency
```bash
# Force cleanup regardless of cost threshold
Actions → Cost Management → action: "cleanup" → force_cleanup: true

# Monitor current costs
Actions → Cost Management → action: "monitor"
```

### 3. Manual K3s Access
```bash
# SSH to K3s node
ssh -i ~/.ssh/aws-key ubuntu@<EC2_PUBLIC_IP>

# Check cluster status
sudo k3s kubectl get nodes
sudo k3s kubectl get pods --all-namespaces
```

> ⚡ **Quick Recovery** - destroy and redeploy takes ~5 minutes at $0 cost

---

## 💸 Cost Control

### **Automated (Recommended)**
```bash
# Weekly automatic monitoring + cleanup
Runs every Monday: 9 AM monitor, 10 AM cleanup

# Manual cost check
Actions → Cost Management → action: "monitor"

# Force cleanup if needed
Actions → Cost Management → action: "cleanup" → force_cleanup: true
```

### **Manual Infrastructure Control**
```bash
# Stop specific environment
Actions → Infrastructure → action: "destroy" → environment: "dev"

# Stop all environments
Actions → Infrastructure → action: "destroy" → environment: "all"

# Restart when needed
Actions → Infrastructure → action: "deploy" → environment: "dev"
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
