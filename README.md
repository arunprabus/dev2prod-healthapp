# Health App Infrastructure

Infrastructure as Code for Health App with EKS, Terraform, and RDS across Dev/Test/Prod environments.

## Architecture

```
┌─────────────────┐    ┌──────────────┐    ┌─────────────┐
│   Frontend      │    │  Health API  │    │ PostgreSQL  │
│   (React)       │◄──►│(Node.js/EKS) │◄──►│ (RDS)       │
└─────────────────┘    └──────────────┘    └─────────────┘
         │                       │                  │
         └───────────────────────┼──────────────────┘
                                 │
                    ┌─────────────▼──────────────┐
                    │      AWS Infrastructure    │
                    │  • EKS Cluster             │
                    │  • VPC with Public/Private │
                    │  • ECR Repository          │
                    │  • ALB Ingress Controller  │
                    │  • AWS Cognito             │
                    └────────────────────────────┘
```

## Components

### Infrastructure Modules
- **VPC**: Network infrastructure with public/private subnets
- **EKS**: Kubernetes cluster for container orchestration
- **ECR**: Container registry for Docker images
- **IAM**: Roles and policies for AWS services
- **DynamoDB**: NoSQL database for application data

### Deployment
- **Kubernetes**: Container orchestration
- **GitHub Actions**: CI/CD pipeline
- **Docker**: Application containerization

## Setup

### GitHub Secrets Required
```bash
AWS_ACCESS_KEY_ID=AKIA...
AWS_SECRET_ACCESS_KEY=...
TF_STATE_BUCKET=health-app-terraform-state-bucket
```

### AWS Prerequisites
```bash
# Create S3 bucket for Terraform state
aws s3 mb s3://health-app-terraform-state-bucket

# Create DynamoDB table for state locking
aws dynamodb create-table --table-name terraform-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST
```

**📋 See [SETUP.md](SETUP.md) for detailed configuration**

## Quick Start

### 1. Deploy Infrastructure
```bash
# Deploy all environments
make infra-up-all

# Deploy specific environment
make infra-up ENV=dev

# Check status
make status-all
```

### 2. Cost Management
```bash
# Destroy all environments (SAVE COSTS)
make shutdown-all

# Destroy specific environment
make infra-down ENV=test
```

### 2. Configure kubectl
```bash
aws eks update-kubeconfig --region ap-south-1 --name health-api-cluster
```

### 3. Install AWS Load Balancer Controller
```bash
kubectl apply -k "github.com/aws/eks-charts/stable/aws-load-balancer-controller/crds?ref=master"

helm repo add eks https://aws.github.io/eks-charts
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=health-api-cluster
```

### 4. Deploy Applications
Applications are deployed via their respective repositories:
- **Backend API**: `health-api` repository
- **Frontend**: `health-frontend` repository

## Environment Management

### Development
- **Namespace**: `dev-{branch-name}`
- **URL**: `{branch-name}.yourdomain.com`
- **Auto-scaling**: 1-2 nodes

### Production
- **Namespace**: `production`
- **URL**: `yourdomain.com`
- **Auto-scaling**: 2-4 nodes

## Repository Structure

```
infra/
├── environments/     # Environment-specific configs
│   ├── dev.tfvars   # Dev environment
│   ├── test.tfvars  # Test environment
│   └── prod.tfvars  # Prod environment
├── modules/         # Terraform modules
│   ├── vpc/         # VPC and networking
│   ├── eks/         # EKS cluster
│   └── rds/         # RDS database
├── main.tf          # Main configuration
├── variables.tf     # Input variables
└── backend.tf       # State backend

.github/workflows/
├── infra-deploy.yml    # Infrastructure deployment
└── infra-shutdown.yml  # Cost-saving shutdown

Makefile            # Infrastructure commands
```

## Network Architecture
- **Dev & Test**: Shared network (10.0.0.0/16)
- **Prod**: Isolated network (10.1.0.0/16)

## Cost Management

### Automatic Shutdown
```bash
# GitHub Actions workflow for complete shutdown
# Requires typing "DESTROY" to confirm
make shutdown-all
```

### Environment-Specific Costs
- **Dev**: t3.small, 1-2 nodes, db.t3.micro
- **Test**: t3.small, 1-3 nodes, db.t3.micro  
- **Prod**: t3.medium, 2-6 nodes, db.t3.small

### Cost Optimization
- Shared network for Dev/Test
- Auto-scaling based on demand
- Easy shutdown workflows

## Security

- **Network**: Private subnets for workloads
- **IAM**: Least privilege access
- **Secrets**: Kubernetes secrets for sensitive data
- **Container**: Non-root user in Docker images

## Monitoring & Logging

- **CloudWatch**: Infrastructure metrics
- **EKS**: Container Insights enabled
- **ALB**: Access logs to S3
- **Application**: Structured logging to CloudWatch

## Disaster Recovery

- **Multi-AZ**: Resources across availability zones
- **Backups**: Automated RDS and DynamoDB backups
- **Infrastructure**: Version-controlled Terraform state
- **Applications**: Blue-green deployments