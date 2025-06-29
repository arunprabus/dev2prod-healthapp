# Environment-Specific Terraform Configurations

## Usage

### Deploy to Dev Environment
```bash
cd envs/dev
terraform init -backend-config=../../backend-configs/dev.tfbackend
terraform plan
terraform apply
```

### Deploy to QA Environment
```bash
cd envs/qa
terraform init -backend-config=../../backend-configs/qa.tfbackend
terraform plan
terraform apply
```

### Deploy to Production Environment
```bash
cd envs/prod
terraform init -backend-config=../../backend-configs/prod.tfbackend
terraform plan
terraform apply
```

## Environment Differences (FREE TIER OPTIMIZED)

| Environment | VPC CIDR | Node Size | Instance Type | RDS Class | Monthly Cost* |
|-------------|----------|-----------|---------------|-----------|---------------|
| **Dev**     | 10.0.0.0/16 | 1 node | t2.micro | db.t3.micro | ~$73 |
| **QA**      | 10.1.0.0/16 | 1 node | t2.micro | db.t3.micro | ~$73 |
| **Prod**    | 10.2.0.0/16 | 1 node | t2.micro | db.t3.micro | ~$73 |

*Cost is for EKS control plane only. EC2 and RDS are free tier.

## 🚨 Cost Warning

**EKS Control Plane costs $0.10/hour (~$73/month) per cluster.**

For learning AWS:
1. **Deploy only ONE environment** (dev recommended)
2. **Destroy when not in use**: `make destroy-dev`
3. **Consider free alternative**: Use `infra/learning-setup` instead

## Network Isolation

Each environment has its own isolated VPC with no cross-environment communication by default.