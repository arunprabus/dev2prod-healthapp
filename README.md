# 🏥 Health App - Two-Network Infrastructure (AWS Free Tier)

> 🚀 Cost-optimized multi-environment K3s + RDS setup with full **network isolation**—ideal for hands-on AWS, Kubernetes, and DevOps training.

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

```bash
# 1. Setup SSH
ssh-keygen -t rsa -f ~/.ssh/id_rsa

# 2. Navigate to infra
cd infra/two-network-setup

# 3. Deploy infra and apps
make deploy-all
make deploy-apps ENV=dev
make deploy-apps ENV=test
make deploy-apps ENV=prod
```

---

## 🌐 Application Access

| Environment | Network       | Frontend         | Backend          | DB Password |
|-------------|---------------|------------------|------------------|-------------|
| Dev         | 10.0.0.0/16   | :30080           | :30081           | `dev123!`   |
| Test        | 10.0.0.0/16   | :30080           | :30081           | `test123!`  |
| Prod        | 10.1.0.0/16   | :30080           | :30081           | `prod123!`  |

---

## 🛠️ Management Commands

| Command | Description |
|--------|-------------|
| `make deploy-lower ENV=dev` | Deploy Dev environment |
| `make deploy-lower ENV=test` | Deploy Test environment |
| `make deploy-higher ENV=prod` | Deploy Prod environment |
| `make ssh ENV=dev` | SSH into Dev |
| `make check-apps ENV=prod` | Check app status |
| `make status` | Show all environments |

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

## 🧪 Learning Highlights

- ⚙️ Kubernetes (K3s) in EC2
- 🗄️ MySQL on RDS integration
- 🔁 Environment lifecycle management
- 🔐 VPC & Subnet configuration
- 💥 Cost-saving strategies

---

**Perfect for mastering real-world AWS multi-env deployment!**
