# Infrastructure Setup Guide

## 🎯 Choose Your Learning Path

### 🆓 Option 1: Free Tier Setup (Recommended for Beginners)
**Cost: $0/month** - Perfect for learning Kubernetes fundamentals

```bash
cd envs/free-tier
make init-free && make apply-free
```

**What you get:**
- K3s Kubernetes cluster on EC2 t2.micro
- RDS MySQL database (db.t3.micro)
- Complete VPC networking
- 100% within AWS free tier

### 💼 Option 2: Production EKS Setup
**Cost: $73/month per environment** - Enterprise-grade setup

```bash
# Single environment
cd envs/dev
make init-dev && make apply-dev

# All environments (dev/qa/prod)
make init-dev && make apply-dev
make init-qa && make apply-qa  
make init-prod && make apply-prod
```

**What you get:**
- Managed EKS clusters
- Blue-green deployments
- Multi-environment isolation
- Production-ready architecture

## 📊 Feature Comparison

| Feature | Free Tier (K3s) | Production (EKS) |
|---------|-----------------|------------------|
| **Cost** | $0/month | $73/month per env |
| **Kubernetes** | ✅ K3s | ✅ Managed EKS |
| **Database** | ✅ RDS MySQL | ✅ RDS MySQL |
| **Networking** | ✅ VPC | ✅ VPC |
| **Auto-scaling** | ❌ Manual | ✅ HPA/VPA |
| **Blue-Green** | ❌ Basic | ✅ Advanced |
| **Multi-env** | ❌ Single | ✅ Dev/QA/Prod |
| **Learning Value** | High | Very High |

## 🚀 Quick Commands

### Free Tier Commands
```bash
make init-free     # Initialize free tier
make apply-free    # Deploy (100% FREE)
make destroy-free  # Clean up
```

### EKS Commands
```bash
make init-dev && make apply-dev      # Dev environment
make init-qa && make apply-qa        # QA environment  
make init-prod && make apply-prod    # Prod environment
```

## 📁 Directory Structure

```
infra/
├── envs/
│   ├── free-tier/    # 🆓 K3s setup ($0/month)
│   ├── dev/          # 💼 EKS dev ($73/month)
│   ├── qa/           # 💼 EKS qa ($73/month)
│   └── prod/         # 💼 EKS prod ($73/month)
├── modules/
│   ├── k3s/          # K3s on EC2 module
│   ├── eks/          # EKS module
│   ├── vpc/          # VPC module
│   └── rds/          # RDS module
└── backend-configs/  # Terraform state configs
```

## 💡 Recommendations

### For AWS Beginners
1. **Start with free-tier**: Learn fundamentals without cost
2. **Master basics**: VPC, EC2, RDS, Security Groups
3. **Understand Kubernetes**: Pods, services, deployments
4. **Then upgrade**: Move to EKS when ready

### For Production Learning
1. **Use single EKS environment**: Start with dev only
2. **Learn blue-green deployments**: Zero-downtime updates
3. **Master auto-scaling**: HPA, VPA, cluster scaling
4. **Add environments**: Expand to QA and prod

## 🔧 Prerequisites

### Free Tier Setup
- AWS CLI configured
- SSH key pair generated
- Basic Terraform knowledge

### EKS Setup
- AWS CLI configured
- GitHub repository secrets
- Docker images ready
- Advanced Terraform knowledge

## 📚 Learning Resources

- [Free Tier Setup Guide](envs/free-tier/README.md)
- [Cost Warning Guide](envs/COST-WARNING.md)
- [Free Tier Features](FREE-TIER-GUIDE.md)

**Start free, learn fundamentals, then scale to production!**