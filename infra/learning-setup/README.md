# Cost-Optimized Learning Setup

## 💰 Cost Breakdown (ap-south-1)

### ✅ FREE TIER (32 hrs/month)
- **EC2 t2.micro**: ₹0 (750 hours free)
- **RDS db.t3.micro**: ₹0 (750 hours free)
- **EBS 20GB**: ₹0 (30GB free)
- **Data Transfer**: ₹0 (1GB free)

### 🎯 **Total Cost: ₹0** (within free tier)

## Architecture

```
┌─────────────────┐    ┌──────────────┐    ┌─────────────┐
│   Your Apps     │    │  K3s Cluster │    │ RDS MySQL   │
│   (Containers)  │◄──►│ (EC2 t2.micro)│◄──►│(db.t3.micro)│
└─────────────────┘    └──────────────┘    └─────────────┘
         │                       │                  │
         └───────────────────────┼──────────────────┘
                                 │
                    ┌─────────────▼──────────────┐
                    │      Single AZ VPC         │
                    │  • Public Subnet Only      │
                    │  • No NAT Gateway          │
                    │  • Internet Gateway        │
                    └────────────────────────────┘
```

## Setup Instructions

### 1. Generate SSH Key
```bash
ssh-keygen -t rsa -f ~/.ssh/id_rsa
```

### 2. Deploy Infrastructure
```bash
cd infra/learning-setup
terraform init
terraform plan
terraform apply
```

### 3. Connect to K3s
```bash
# SSH to instance
ssh -i ~/.ssh/id_rsa ubuntu@<PUBLIC_IP>

# Check K3s status
sudo kubectl get nodes

# Deploy sample app
sudo kubectl create deployment nginx --image=nginx
sudo kubectl expose deployment nginx --port=80 --type=NodePort
```

### 4. Auto-Stop Features
- **Daily auto-stop**: 10:30 PM IST
- **Manual stop**: `terraform destroy`
- **Start again**: `terraform apply`

## Cost Optimization Features

### ✅ Implemented
- **Single AZ**: No cross-AZ charges
- **Public subnet only**: No NAT Gateway (₹2,400/month saved)
- **t2.micro instances**: Free tier eligible
- **No encryption**: Saves storage costs
- **No backups**: Saves backup costs
- **Auto-stop Lambda**: Prevents idle charges

### ✅ Free Tier Monitoring
```bash
# Check free tier usage
aws support describe-trusted-advisor-checks
```

## Learning Exercises

### 1. Deploy Applications
```bash
# Deploy your health app
sudo kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: health-api
spec:
  replicas: 1
  selector:
    matchLabels:
      app: health-api
  template:
    metadata:
      labels:
        app: health-api
    spec:
      containers:
      - name: health-api
        image: nginx
        ports:
        - containerPort: 80
EOF
```

### 2. Database Connection
```bash
# Connect to RDS from K3s pod
mysql -h <RDS_ENDPOINT> -u admin -p learningdb
```

### 3. Scaling Tests
```bash
# Scale deployment
sudo kubectl scale deployment health-api --replicas=2
```

## Manual Cost Controls

### Start Resources
```bash
# Start EC2
aws ec2 start-instances --instance-ids <INSTANCE_ID>

# Start RDS
aws rds start-db-instance --db-instance-identifier learning-db
```

### Stop Resources
```bash
# Stop EC2
aws ec2 stop-instances --instance-ids <INSTANCE_ID>

# Stop RDS
aws rds stop-db-instance --db-instance-identifier learning-db
```

### Destroy Everything
```bash
terraform destroy
```

## Monitoring Costs

### Set Billing Alerts
1. Go to AWS Billing Console
2. Set alert for ₹100/month
3. Monitor Free Tier usage

### Daily Checks
```bash
# Check running instances
aws ec2 describe-instances --query 'Reservations[].Instances[?State.Name==`running`]'

# Check RDS status
aws rds describe-db-instances --query 'DBInstances[?DBInstanceStatus==`available`]'
```

## Alternative: Pure Local Development

If you want ₹0 cost:
```bash
# Local K3s with Docker
curl -sfL https://get.k3s.io | sh -
docker run -d --name mysql -e MYSQL_ROOT_PASSWORD=root mysql:8.0
```

This setup gives you **real AWS experience** while staying within free tier limits!