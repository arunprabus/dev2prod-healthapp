# ⚠️ COST WARNING - READ BEFORE DEPLOYING

## 🚨 EKS IS NOT FREE TIER

**EKS Control Plane costs $0.10/hour = ~$73/month per cluster**

## 💰 Cost Breakdown

### If you deploy ALL environments:
- Dev EKS: $73/month
- QA EKS: $73/month  
- Prod EKS: $73/month
- **Total: $219/month**

### If you deploy ONE environment:
- Single EKS: $73/month
- EC2 t2.micro: $0 (free tier)
- RDS db.t3.micro: $0 (free tier)
- **Total: $73/month**

## 🎯 Recommended for Learning

### Option 1: Single Environment (Minimal Cost)
```bash
# Deploy only dev environment
make init-dev && make apply-dev

# When done learning for the day
make destroy-dev
```

### Option 2: Use Free Alternative
```bash
# Use the learning setup instead (100% free)
cd ../learning-setup
make deploy
```

## 🔔 Set Up Billing Alerts

1. Go to AWS Billing Dashboard
2. Set up budget alert for $10
3. Monitor daily costs

## ⏰ Best Practices

1. **Deploy only when actively learning**
2. **Destroy resources after each session**
3. **Use only ONE environment**
4. **Check AWS billing daily**

## 🆓 Free Tier Alternative

The `learning-setup` directory contains a pure free-tier setup:
- EC2 t2.micro with K3s
- RDS db.t3.micro
- **Total cost: $0**

**Choose wisely based on your learning budget!**