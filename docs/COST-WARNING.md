# ⚠️ AWS COST WARNING

## EKS IS NOT FREE!

### Monthly Costs (Minimum)
- **EKS Control Plane**: $72/month (Always charged)
- **NAT Gateway**: $32/month (Always charged)
- **Total Minimum**: ~$104/month

### Free Tier Resources
- **EC2 t3.micro**: 750 hours/month FREE
- **RDS db.t3.micro**: 750 hours/month FREE  
- **S3**: 5GB storage FREE
- **DynamoDB**: 25GB storage FREE

## Cost-Saving Recommendations

### Option 1: Use Only Dev Environment
```bash
# Deploy only dev (not test/prod)
make infra-up ENV=dev
```

### Option 2: Alternative Free Architecture
Consider using:
- **EC2 + Docker Compose** instead of EKS
- **Local development** with Docker
- **Serverless** with Lambda + API Gateway

### Option 3: Shutdown When Not Using
```bash
# Destroy everything when not needed
make shutdown-all
```

## Free Tier Monitoring
- Set up **AWS Billing Alerts**
- Monitor usage in **AWS Cost Explorer**
- Use **AWS Free Tier Dashboard**

## Recommendation
**Start with local Docker development** and only deploy to AWS when needed for testing/demo purposes.