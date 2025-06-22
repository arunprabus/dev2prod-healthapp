# Health App - Two-Network Infrastructure

> **Cost-optimized learning setup with complete network isolation**

## 🏗️ Network Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                        AWS Region: ap-south-1                      │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │              LOWER NETWORK (10.0.0.0/16)                   │    │
│  │                                                             │    │
│  │  ┌─────────────────────┐    ┌─────────────────────┐        │    │
│  │  │    DEV Environment  │    │   TEST Environment  │        │    │
│  │  │                     │    │                     │        │    │
│  │  │  ┌───────────────┐  │    │  ┌───────────────┐  │        │    │
│  │  │  │ K3s Cluster   │  │    │  │ K3s Cluster   │  │        │    │
│  │  │  │ (t2.micro)    │  │    │  │ (t2.micro)    │  │        │    │
│  │  │  │               │  │    │  │               │  │        │    │
│  │  │  │ Frontend:30080│  │    │  │ Frontend:30080│  │        │    │
│  │  │  │ Backend:30081 │  │    │  │ Backend:30081 │  │        │    │
│  │  │  └───────────────┘  │    │  └───────────────┘  │        │    │
│  │  │          │          │    │          │          │        │    │
│  │  │  ┌───────▼───────┐  │    │  ┌───────▼───────┐  │        │    │
│  │  │  │ MySQL RDS     │  │    │  │ MySQL RDS     │  │        │    │
│  │  │  │ (db.t3.micro) │  │    │  │ (db.t3.micro) │  │        │    │
│  │  │  └───────────────┘  │    │  └───────────────┘  │        │    │
│  │  └─────────────────────┘    └─────────────────────┘        │    │
│  └─────────────────────────────────────────────────────────────┘    │
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │              HIGHER NETWORK (10.1.0.0/16)                  │    │
│  │                                                             │    │
│  │              ┌─────────────────────┐                       │    │
│  │              │   PROD Environment  │                       │    │
│  │              │                     │                       │    │
│  │              │  ┌───────────────┐  │                       │    │
│  │              │  │ K3s Cluster   │  │                       │    │
│  │              │  │ (t2.micro)    │  │                       │    │
│  │              │  │               │  │                       │    │
│  │              │  │ Frontend:30080│  │                       │    │
│  │              │  │ Backend:30081 │  │                       │    │
│  │              │  └───────────────┘  │                       │    │
│  │              │          │          │                       │    │
│  │              │  ┌───────▼───────┐  │                       │    │
│  │              │  │ MySQL RDS     │  │                       │    │
│  │              │  │ (db.t3.micro) │  │                       │    │
│  │              │  └───────────────┘  │                       │    │
│  │              └─────────────────────┘                       │    │
│  └─────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────┘
```

## 💰 **Cost: ₹0** (Free Tier)

| Resource | Quantity | Free Tier | Cost |
|----------|----------|-----------|------|
| EC2 t2.micro | 3 instances | 750 hrs/month | ₹0 |
| RDS db.t3.micro | 3 databases | 750 hrs/month | ₹0 |
| VPC | 2 networks | Unlimited | ₹0 |
| EBS Storage | 60GB total | 30GB free | ₹0* |

*Within 32 hours/month usage

## 🚀 Quick Start

```bash
# 1. Setup
ssh-keygen -t rsa -f ~/.ssh/id_rsa
cd infra/two-network-setup

# 2. Deploy Everything
make deploy-all

# 3. Deploy Apps
make deploy-apps ENV=dev
make deploy-apps ENV=test  
make deploy-apps ENV=prod

# 4. Access Applications
# Dev: http://<dev-ip>:30080
# Test: http://<test-ip>:30080
# Prod: http://<prod-ip>:30080
```

## 🎯 Environment Management

| Command | Description |
|---------|-------------|
| `make deploy-lower ENV=dev` | Deploy dev in lower network |
| `make deploy-lower ENV=test` | Deploy test in lower network |
| `make deploy-higher ENV=prod` | Deploy prod in higher network |
| `make ssh ENV=dev` | SSH to dev environment |
| `make check-apps ENV=prod` | Check prod applications |
| `make status` | Show all environments |

## 🌐 Application Access

| Environment | Network | Frontend | Backend | Database |
|-------------|---------|----------|---------|----------|
| **Dev** | Lower (10.0.x.x) | :30080 | :30081 | dev123! |
| **Test** | Lower (10.0.x.x) | :30080 | :30081 | test123! |
| **Prod** | Higher (10.1.x.x) | :30080 | :30081 | prod123! |

## 🔒 Network Isolation

### Two-Tier Security Model
- **Lower Tier**: Dev + Test (10.0.0.0/16) - Shared network, isolated environments
- **Higher Tier**: Production (10.1.0.0/16) - Completely separate network
- **Zero Communication**: Networks cannot communicate with each other
- **Cost Optimized**: Public subnets only, no NAT Gateway costs

## 💸 Cost Control

```bash
# Stop everything (save costs)
make stop-all

# Start when needed  
make start-all

# Nuclear option
make destroy-all
```

## 🔄 Development Workflow

1. **Develop** → Deploy to dev environment
2. **Test** → Validate in test environment  
3. **Production** → Deploy to isolated prod network

## 🗄️ Database Access

```bash
# SSH to any environment
make ssh ENV=dev

# Connect to MySQL
mysql -h <rds-endpoint> -u admin -p healthapp
```

## 🔍 Monitoring

| Command | Purpose |
|---------|----------|
| `make status` | Overall status |
| `make check-apps ENV=dev` | App status |
| `make test-connectivity` | Network test |
| `sudo kubectl get pods` | K3s status |

## 🛡️ Security & Learning

### Security Features
- ✅ Complete network isolation between dev/test and prod
- ✅ Security groups with minimal required ports
- ✅ SSH key-based authentication
- ✅ No cross-network communication possible

### Learning Opportunities
- 🎯 Multi-environment deployments
- 🎯 Network isolation concepts
- 🎯 Kubernetes application management
- 🎯 Database integration patterns
- 🎯 Infrastructure as Code with Terraform

---

**Perfect for learning AWS, Kubernetes, and multi-environment architecture while staying within free tier limits!** 🚀