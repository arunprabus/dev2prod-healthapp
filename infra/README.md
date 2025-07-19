# Health App Infrastructure

This directory contains the infrastructure code for the Health App platform, configured for Kubernetes (K3s) instead of EKS for cost-effective, production-ready deployments.

## Directory Structure

```
├── backend-configs/         # Terraform state configurations
├── environments/            # Environment-specific variables
├── modules/                 # Reusable Terraform modules
│   ├── argo-rollouts/       # Progressive delivery with Argo Rollouts
│   ├── deployment/          # Application deployment
│   ├── github-runner/       # Self-hosted GitHub runners
│   ├── k3s/                 # K3s cluster setup
│   ├── lambda/              # AWS Lambda functions for automation
│   ├── monitoring/          # Prometheus + Grafana monitoring
│   ├── rds/                 # Database setup
│   ├── vpc/                 # Network configuration
│   └── vpc_peering/         # VPC peering connections
├── three-tier-network/      # Three-tier network architecture
│   ├── environments/        # Network-specific configurations
│   ├── main.tf              # Main Terraform configuration
│   ├── outputs.tf           # Output values
│   ├── variables.tf         # Input variables
│   └── README.md            # Network architecture documentation
├── backend.tf               # Terraform backend configuration
├── locals.tf                # Local variables and naming conventions
├── main.tf                  # Main Terraform configuration
├── outputs.tf               # Output values
├── variables.tf             # Input variables
└── variables-tags.tf        # Resource tagging variables
```

## Network Architecture

The infrastructure is organized into a three-tier network architecture:

1. **Lower Network** - Contains Dev and Test environments with shared database
2. **Higher Network** - Contains Production environment with dedicated database
3. **Monitoring Network** - Contains centralized monitoring and connects to both networks

For detailed information about the three-tier network architecture, see the [three-tier-network/README.md](./three-tier-network/README.md) file.

## Deployment Options

You can deploy the infrastructure using either:

1. **Root Directory** - Deploy individual environments using the main.tf in the root directory
2. **Three-Tier Network** - Deploy the complete three-tier architecture using the three-tier-network directory

### Option 1: Individual Environment Deployment

```bash
# Initialize Terraform
terraform init -backend-config=backend-configs/dev.tfbackend

# Deploy Dev Environment
terraform apply -var-file=environments/dev.tfvars
```

### Option 2: Three-Tier Network Deployment

```bash
# Change to the three-tier-network directory
cd three-tier-network

# Initialize Terraform
terraform init

# Deploy Lower Network (Dev + Test)
terraform apply -var-file=environments/lower.tfvars

# Deploy Higher Network (Production)
terraform apply -var-file=environments/higher.tfvars

# Deploy Monitoring Network
terraform apply -var-file=environments/monitoring.tfvars
```

## Modules

The infrastructure is organized into reusable modules:

- **vpc** - Network configuration with public and private subnets
- **k3s** - Lightweight Kubernetes cluster setup
- **rds** - Database setup with backup and restore capabilities
- **github-runner** - Self-hosted GitHub runners for CI/CD
- **monitoring** - Prometheus and Grafana monitoring stack
- **argo-rollouts** - Progressive delivery with canary and blue/green deployments
- **lambda** - AWS Lambda functions for cost optimization and automation
- **vpc_peering** - VPC peering connections for network communication