# 🏥 Health App - Production-Ready Infrastructure with Blue-Green Deployment

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
│ │ │ K3s + RDS    │     │ K3s + RDS    │                           │   │
│ │ └──────────────┘     └──────────────┘                           │   │
│ └─────────────────────────────────────────────────────────────────┘   │
│                                                                       │
│ ┌─────────────────────────────────────────────────────────────────┐   │
│ │                HIGHER NETWORK (10.1.0.0/16)                     │   │
│ │ ┌──────────────┐                                               │   │
│ │ │  PROD ENV    │                                               │   │
│ │ │ K3s + RDS    │                                               │   │
│ │ └──────────────┘                                               │   │
│ └─────────────────────────────────────────────────────────────────┘   │
└───────────────────────────────────────────────────────────────────────┘
```

---

## 💰 Free Tier Resource Usage

| Resource        | Quantity | Free Tier | Cost |
|----------------|----------|-----------|------|
| EC2 t2.micro    | 3        | 750 hrs   | ₹0   |
| RDS db.t3.micro | 3        | 750 hrs   | ₹0   |
| VPCs            | 2        | Unlimited | ₹0   |
| EBS             | 60GB     | 30GB Free | ₹0\* |

\*Assuming 32 hrs/month usage

---

## 🚀 Quick Start

### Prerequisites
- AWS CLI configured
- GitHub environments and variables configured
- GitHub repository secrets configured
- Docker images pushed to container registry

```bash
# 1. Clone repository
git clone <your-repo-url>
cd dev2prod-healthapp

# 2. Configure GitHub Environments & Variables
# See ENVIRONMENT-SETUP.md for detailed configuration

# 3. Configure GitHub Secrets
# AWS_ACCESS_KEY_ID
# AWS_SECRET_ACCESS_KEY
# SLACK_WEBHOOK_URL

# 4. Deploy via GitHub Actions
# Go to Actions → Deploy to EKS → Run workflow
```

## ⚙️ Configuration Management

### **Environment Variables (Configurable)**
| Variable | Default | Purpose |
|----------|---------|----------|
| `AWS_REGION` | `ap-south-1` | Deployment region |
| `EKS_CLUSTER_NAME` | `health-app-cluster` | Cluster base name |
| `CONTAINER_REGISTRY` | `ghcr.io` | Container registry |
| `REGISTRY_NAMESPACE` | `arunprabus` | Registry namespace |
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
│   └── environments/     # Environment configs
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

**🎓 Perfect for mastering enterprise-grade deployment strategies!**
