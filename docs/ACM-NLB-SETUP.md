# 🔒 ACM + NLB Setup for K3s API

## Architecture Overview

```
kubectl <--HTTPS(ACM cert)--> NLB <--HTTP--> K3s EC2:6443
```

## Benefits
- ✅ **Fully encrypted** via ACM certificate
- ✅ **No self-signed certificates** to manage
- ✅ **Domain-based access** (k3s.yourdomain.com)
- ✅ **Production-ready** SSL/TLS termination
- ✅ **Cost-effective** (~$18/month for NLB)

## Quick Setup

### 1. Configure Domain (Optional)
```bash
# If you have a domain, set these variables:
export K3S_DOMAIN="k3s-dev.yourdomain.com"
export ROUTE53_ZONE_ID="Z1234567890ABC"

# For testing without domain:
export K3S_DOMAIN="k3s.local"
export ROUTE53_ZONE_ID=""
```

### 2. Deploy Infrastructure
```bash
# Deploy with ACM + NLB
cd infra/live
terraform apply \
  -var="k3s_domain_name=$K3S_DOMAIN" \
  -var="route53_zone_id=$ROUTE53_ZONE_ID"
```

### 3. DNS Validation (Manual)
If you don't have Route53, manually add DNS records:
```bash
# Get validation records from output
terraform output certificate_validation

# Add CNAME records to your DNS provider
# Name: _abc123.k3s-dev.yourdomain.com
# Value: _xyz789.acm-validations.aws.
```

### 4. Setup Kubeconfig
```bash
# Get NLB DNS name
NLB_DNS=$(terraform output -raw nlb_dns_name)

# Setup kubeconfig
./scripts/setup-nlb-kubeconfig.sh dev $NLB_DNS

# Get K3s token from cluster
ssh -i ~/.ssh/k3s-key ubuntu@$(terraform output -raw k3s_public_ip)
sudo cat /var/lib/rancher/k3s/server/node-token

# Update kubeconfig with real token
sed -i 's/PLACEHOLDER_TOKEN/K3S_TOKEN_HERE/' ~/.kube/config-dev

# Test connection
kubectl --kubeconfig ~/.kube/config-dev get nodes
```

## Security Configuration

### K3s Security Group
- ✅ **Port 6443**: Only accessible from NLB security group
- ✅ **No direct internet access** to K3s API
- ✅ **SSH access**: For management only

### NLB Configuration
- ✅ **HTTPS listener**: Port 443 with ACM certificate
- ✅ **Target group**: Forwards to K3s instance port 6443
- ✅ **Health checks**: Monitors K3s API health

## Cost Analysis

| Component | Monthly Cost | Free Tier |
|-----------|-------------|-----------|
| **NLB** | ~$18 | ❌ Not free |
| **ACM Certificate** | $0 | ✅ Always free |
| **Route53 (optional)** | $0.50 | ❌ Not free |
| **K3s EC2** | $0 | ✅ Free tier |
| **Total** | **~$18-19/month** | |

### vs Direct Access
- **Direct K3s**: $0/month (self-signed certs)
- **ACM + NLB**: $18/month (production SSL)
- **Trade-off**: Cost vs Professional SSL

## Troubleshooting

### Certificate Issues
```bash
# Check certificate status
aws acm describe-certificate --certificate-arn $(terraform output -raw certificate_arn)

# Manual DNS validation
aws acm describe-certificate --certificate-arn $(terraform output -raw certificate_arn) \
  --query 'Certificate.DomainValidationOptions'
```

### NLB Health Checks
```bash
# Check target group health
aws elbv2 describe-target-health --target-group-arn $(terraform output -raw target_group_arn)

# Test K3s API directly
curl -k https://$(terraform output -raw k3s_public_ip):6443/readyz
```

### Connection Issues
```bash
# Test NLB endpoint
curl -v https://$(terraform output -raw nlb_dns_name):443/readyz

# Check security groups
aws ec2 describe-security-groups --group-ids $(terraform output -raw k3s_security_group_id)
```

## Production Recommendations

1. **Use Route53** for automatic DNS validation
2. **Enable NLB access logs** for monitoring
3. **Set up CloudWatch alarms** for NLB health
4. **Use dedicated domain** (not k3s.local)
5. **Enable deletion protection** on NLB for production