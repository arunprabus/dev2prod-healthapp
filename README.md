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
- GitHub repository secrets configured
- Docker images pushed to GHCR

```bash
# 1. Clone repository
git clone <your-repo-url>
cd dev2prod-healthapp

# 2. Configure GitHub Secrets
# AWS_ACCESS_KEY_ID
# AWS_SECRET_ACCESS_KEY

# 3. Deploy via GitHub Actions
# Go to Actions → Deploy to EKS → Run workflow
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
| `Infrastructure Deploy` | Manual | Terraform infrastructure setup |
| `Infrastructure Shutdown` | Manual | Cost-saving resource cleanup |

### Manual Operations
```bash
# Check deployment status
kubectl get deployments
kubectl get services

# View current active color
kubectl get service health-api-service -o jsonpath='{.spec.selector.color}'

# Manual rollback (if needed)
kubectl patch service health-api-service -p '{"spec":{"selector":{"color":"blue"}}}'
```

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
│   ├── canary-rollout.yaml      # Advanced deployment
│   └── argocd-app.yaml          # GitOps setup
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

## 🧪 Learning Highlights

- 🔄 **Blue-Green Deployment**: Zero-downtime deployments
- ⚙️ **EKS Management**: Production Kubernetes
- 🗄️ **DynamoDB + S3**: Serverless data layer
- 🔁 **Multi-environment**: Dev/Test/Prod isolation
- 🔐 **Security**: IAM roles, secrets management
- 📊 **Monitoring**: Health checks, rollback automation
- 🚀 **CI/CD**: GitHub Actions automation

## 🎯 Deployment Strategies Comparison

| Strategy | Downtime | Risk | Complexity | Use Case |
|----------|----------|------|------------|----------|
| Rolling | Minimal | Medium | Low | Development |
| Blue-Green | Zero | Low | Medium | **Current Setup** |
| Canary | Zero | Very Low | High | Production |
| A/B Testing | Zero | Low | High | Feature testing |

---

**🎓 Perfect for mastering enterprise-grade deployment strategies!**
