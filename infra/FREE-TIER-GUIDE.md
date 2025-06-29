# AWS Free Tier Configuration Guide

## 🆓 Free Tier Resources Used

### EC2 (EKS Nodes)
- **Instance Type**: t2.micro
- **Free Tier**: 750 hours/month
- **Configuration**: 1 node per environment
- **Cost**: $0 (within free tier limits)

### RDS Database
- **Instance Type**: db.t3.micro
- **Free Tier**: 750 hours/month
- **Storage**: 20GB (within 20GB free tier)
- **Configuration**: 
  - No encryption (not available in free tier)
  - No automated backups (to stay within limits)
- **Cost**: $0 (within free tier limits)

### VPC & Networking
- **VPC**: Free (unlimited)
- **Subnets**: Free (unlimited)
- **Internet Gateway**: Free (1 per VPC)
- **Route Tables**: Free (unlimited)
- **Security Groups**: Free (unlimited)

### EKS Control Plane
- **Cost**: $0.10/hour per cluster
- **Monthly Cost**: ~$73/month per cluster
- **⚠️ NOT FREE TIER**

## 💰 Estimated Monthly Costs

| Environment | EKS Control Plane | EC2 | RDS | Total |
|-------------|-------------------|-----|-----|-------|
| **Dev**     | $73               | $0  | $0  | $73   |
| **QA**      | $73               | $0  | $0  | $73   |
| **Prod**    | $73               | $0  | $0  | $73   |
| **Total**   | $219              | $0  | $0  | $219  |

## 🎯 Cost Optimization Tips

### 1. Use Single Environment for Learning
```bash
# Deploy only dev environment
make init-dev && make apply-dev

# Destroy when not in use
make destroy-dev
```

### 2. Alternative: Use EC2 Instead of EKS
- Replace EKS with single EC2 t2.micro instance
- Install K3s (lightweight Kubernetes)
- **Cost**: $0 (within free tier)

### 3. Scheduled Shutdown
```bash
# Stop instances at night (save ~16 hours/day)
aws ec2 stop-instances --instance-ids <instance-id>

# Start when needed
aws ec2 start-instances --instance-ids <instance-id>
```

## 🚨 Free Tier Warnings

### EC2 Limits
- **750 hours/month** = ~31 days of 1 instance
- **Multiple instances** = hours divided among them
- **t2.micro only** - other types are charged

### RDS Limits
- **750 hours/month** of db.t3.micro
- **20GB storage** maximum
- **No Multi-AZ** (not free)
- **No encryption** (not free)

### EKS Reality
- **EKS Control Plane** is NOT free tier
- **$0.10/hour** regardless of usage
- **Consider alternatives** for learning

## 💡 Learning-Optimized Setup

### Option 1: Minimal EKS (Paid)
```bash
# Single environment only
make init-dev && make apply-dev
# Cost: ~$73/month
```

### Option 2: EC2 + K3s (Free)
```bash
# Use learning-setup instead
cd infra/learning-setup
make deploy
# Cost: $0 (pure free tier)
```

## ⏰ Usage Recommendations

1. **Deploy only when learning**
2. **Destroy after each session**
3. **Use single environment**
4. **Monitor AWS billing dashboard**
5. **Set up billing alerts**

## 🔔 Billing Alerts Setup

```bash
# Set up $10 billing alert
aws budgets create-budget --account-id <account-id> --budget '{
  "BudgetName": "Learning-Budget",
  "BudgetLimit": {"Amount": "10", "Unit": "USD"},
  "TimeUnit": "MONTHLY",
  "BudgetType": "COST"
}'
```

**Remember: EKS is great for learning but costs money. Consider the free alternatives for initial AWS learning!**