# Infrastructure Management
# Health App Infrastructure

This directory contains the Terraform configuration for the Health App infrastructure across multiple environments.

## Architecture

The infrastructure follows a modular design with the following components:

- **VPC**: Network infrastructure with public and private subnets
- **EKS**: Kubernetes clusters for container orchestration
- **RDS**: Database instances for application data
- **Monitoring**: Prometheus, Grafana, and centralized logging (optional)
- **Deployment**: Kubernetes and ArgoCD configurations

## Environment Configurations

Each environment has its own configuration file in the `environments` directory:

- `dev.tfvars`: Development environment
- `test.tfvars`: Testing/QA environment
- `prod.tfvars`: Production environment

## Deployment

### Prerequisites

- Terraform 1.6.0 or later
- AWS CLI configured with appropriate credentials
- kubectl

### Deployment Steps

1. Initialize Terraform:

```bash
terraform init \
  -backend-config="bucket=your-terraform-state-bucket" \
  -backend-config="key=health-app-[env].tfstate" \
  -backend-config="region=ap-south-1"
```

2. Apply the configuration:

```bash
terraform apply -var-file="environments/[env].tfvars"
```

Where `[env]` is one of: `dev`, `test`, or `prod`.

## Outputs

After successful deployment, Terraform will output important information including:

- VPC and subnet IDs
- EKS cluster endpoint and credentials
- RDS database endpoint
- Kubernetes namespace
- Monitoring endpoints (if enabled)

## Network Architecture

The infrastructure uses a multi-VPC architecture:

- **Lower Network (10.0.0.0/16)**: Dev and Test environments
- **Higher Network (10.1.0.0/16)**: Production environment
- **Monitoring Network (10.3.0.0/16)**: Centralized monitoring (optional)

## Blue-Green Deployment

The production environment is configured for blue-green deployments with zero downtime. The active deployment color is available as an output variable.

## Security

- EKS clusters use IAM roles for service accounts
- RDS instances use security groups to limit access
- Network isolation between environments
- RBAC configured for Kubernetes resources

## Modules

- `vpc`: Network configuration
- `eks`: Kubernetes cluster configuration
- `rds`: Database configuration
- `deployment`: Application deployment configuration
- `monitoring`: Monitoring and logging configuration
- `vpc_peering`: VPC peering configuration for cross-VPC communication

## Maintenance

To update the infrastructure:

1. Modify the appropriate module or variable
2. Run `terraform plan -var-file="environments/[env].tfvars"` to preview changes
3. Run `terraform apply -var-file="environments/[env].tfvars"` to apply changes

To destroy the infrastructure (use with caution):

```bash
terraform destroy -var-file="environments/[env].tfvars"
```
This directory contains Terraform configurations for managing AWS infrastructure across three environments:

## Network Architecture
- **Dev & Test**: Shared network (10.0.0.0/16)
- **Prod**: Isolated network (10.1.0.0/16)

## Environments
- **dev**: Development environment
- **test**: Testing environment  
- **prod**: Production environment

## Usage
```bash
# Deploy all environments
make infra-up-all

# Deploy specific environment
make infra-up ENV=dev

# Destroy all environments
make infra-down-all

# Destroy specific environment
make infra-down ENV=prod
```