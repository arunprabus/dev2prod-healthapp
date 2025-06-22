# 🌐 Two-Network Architecture Setup

## Architecture Overview

```
Lower Environment Network (10.0.0.0/16)
├── Dev Environment
│   ├── K3s Cluster (EC2 t2.micro)
│   │   ├── Frontend App (Port 30080)
│   │   └── Backend App (Port 30081)
│   └── MySQL Database (RDS db.t3.micro)
└── Test Environment
    ├── K3s Cluster (EC2 t2.micro)
    │   ├── Frontend App (Port 30080)
    │   └── Backend App (Port 30081)
    └── MySQL Database (RDS db.t3.micro)

Higher Environment Network (10.1.0.0/16)
└── Prod Environment
    ├── K3s Cluster (EC2 t2.micro)
    │   ├── Frontend App (Port 30080)
    │   └── Backend App (Port 30081)
    └── MySQL Database (RDS db.t3.micro)
```

## 💰 Cost Analysis

### ✅ **Total Cost: ₹0** (within free tier for 32 hrs/month)

- **3 EC2 t2.micro**: ₹0 (750 hours free tier covers all)
- **3 RDS db.t3.micro**: ₹0 (750 hours free tier covers all)
- **2 VPCs**: ₹0 (no VPC charges)
- **Public subnets only**: ₹0 (no NAT Gateway costs)
- **Single AZ per environment**: ₹0 (no cross-AZ charges)

## Quick Start

### 1. Prerequisites
```bash
# Generate SSH key
ssh-keygen -t rsa -f ~/.ssh/id_rsa

# Ensure AWS CLI is configured
aws configure
```

### 2. Deploy All Environments
```bash
cd infra/two-network-setup

# Deploy all environments
make deploy-all

# Check status
make status
```

### 3. Deploy Applications
```bash
# Deploy apps to dev environment
make deploy-apps ENV=dev

# Deploy apps to test environment
make deploy-apps ENV=test

# Deploy apps to prod environment
make deploy-apps ENV=prod
```

## Individual Environment Management

### Deploy Specific Environment
```bash
# Deploy dev in lower network
make deploy-lower ENV=dev

# Deploy test in lower network
make deploy-lower ENV=test

# Deploy prod in higher network
make deploy-higher ENV=prod
```

### Access Environments
```bash
# SSH to dev environment
make ssh ENV=dev

# SSH to test environment
make ssh ENV=test

# SSH to prod environment
make ssh ENV=prod
```

### Check Applications
```bash
# Check dev apps
make check-apps ENV=dev

# Check test apps
make check-apps ENV=test

# Check prod apps
make check-apps ENV=prod
```

## Application URLs

After deployment, access your applications:

### Dev Environment
- **Frontend**: `http://<dev-ip>:30080`
- **Backend**: `http://<dev-ip>:30081`

### Test Environment
- **Frontend**: `http://<test-ip>:30080`
- **Backend**: `http://<test-ip>:30081`

### Prod Environment
- **Frontend**: `http://<prod-ip>:30080`
- **Backend**: `http://<prod-ip>:30081`

## Network Isolation

### Lower Network (Dev + Test)
- **CIDR**: 10.0.0.0/16
- **Shared resources**: None (each environment isolated)
- **Communication**: Environments cannot communicate directly

### Higher Network (Prod)
- **CIDR**: 10.1.0.0/16
- **Isolation**: Completely separate from dev/test
- **Security**: Production workloads isolated

## Cost Management

### Stop All Resources (Save Costs)
```bash
# Stop all EC2 instances
make stop-all

# Start when needed
make start-all
```

### Destroy Everything
```bash
# Destroy all environments
make destroy-all
```

## Development Workflow

### 1. Develop in Dev Environment
```bash
make deploy-lower ENV=dev
make deploy-apps ENV=dev
# Access: http://<dev-ip>:30080
```

### 2. Test in Test Environment
```bash
make deploy-lower ENV=test
make deploy-apps ENV=test
# Access: http://<test-ip>:30080
```

### 3. Deploy to Production
```bash
make deploy-higher ENV=prod
make deploy-apps ENV=prod
# Access: http://<prod-ip>:30080
```

## Database Access

### Connect to Database from K3s
```bash
# SSH to environment
make ssh ENV=dev

# Connect to MySQL
mysql -h <rds-endpoint> -u admin -p healthapp
# Password: dev123! (for dev), test123! (for test), prod123! (for prod)
```

## Monitoring and Troubleshooting

### Check Resource Status
```bash
# Overall status
make status

# Check applications
make check-apps ENV=dev
```

### View Logs
```bash
# SSH to environment
make ssh ENV=dev

# Check K3s logs
sudo kubectl logs -l app=frontend
sudo kubectl logs -l app=backend
```

### Test Network Connectivity
```bash
make test-connectivity
```

## Security Features

- **Network isolation**: Prod completely separate from dev/test
- **Security groups**: Restrict access to necessary ports only
- **Public subnets**: Direct internet access (cost-optimized)
- **SSH key authentication**: Secure access to instances

## Learning Exercises

1. **Deploy custom applications** to each environment
2. **Test database connectivity** from applications
3. **Practice Kubernetes commands** in each cluster
4. **Simulate production deployments** across networks
5. **Monitor costs** and resource usage

This setup provides **real-world experience** with multi-environment architecture while staying within AWS free tier limits!