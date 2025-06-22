# Health API Infrastructure

Infrastructure as Code for the Health API platform using Terraform and Kubernetes.

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

## Quick Start

### 1. Deploy Infrastructure
```bash
cd terraform
terraform init
terraform plan
terraform apply
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
terraform/
├── vpc/           # VPC and networking
├── eks/           # EKS cluster configuration
├── ecr/           # Container registry
├── iam/           # IAM roles and policies
├── dynamodb/      # DynamoDB tables
├── main.tf        # Main configuration
├── variables.tf   # Input variables
└── outputs.tf     # Output values

k8s/
├── frontend-deployment.yaml
└── health-api-deployment.yaml

.github/workflows/
└── deploy.yml     # Infrastructure deployment pipeline
```

## Cost Optimization

- **EKS**: t3.medium instances with auto-scaling
- **ECR**: Lifecycle policies to clean old images
- **VPC**: NAT Gateways only in required AZs
- **Monitoring**: CloudWatch for cost tracking

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