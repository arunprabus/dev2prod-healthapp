# Simple EC2 with SSH Access

## Quick Deploy

```bash
# Initialize Terraform
terraform init

# Deploy with your SSH key
terraform apply -var="ssh_public_key=$(cat ~/.ssh/id_rsa.pub)"

# Get instance IP
terraform output instance_ip

# SSH to instance
ssh -i ~/.ssh/id_rsa ubuntu@$(terraform output -raw instance_ip)

# Cleanup
terraform destroy -var="ssh_public_key=$(cat ~/.ssh/id_rsa.pub)"
```

## What you get
- **t2.micro EC2** (FREE TIER)
- **SSH access** with your key
- **Ubuntu 22.04 LTS**
- **Security group** for SSH (port 22)

**Cost: $0/month** (within AWS free tier)