# 🏥 Health App Infrastructure Repository

## Production-Ready K8s Infrastructure with Complete DevOps Pipeline

This repository contains the complete infrastructure and deployment pipeline for the Health App platform, configured for **Kubernetes (K8s) instead of EKS** for cost-effective, production-ready deployments.

## 🚀 **Key Features**

- ✅ **K8s Native Deployment** - Direct Kubernetes without EKS overhead
- ✅ **Multi-Environment Support** - dev/test/prod isolation
- ✅ **Auto-Scaling & Monitoring** - HPA, health checks, Prometheus
- ✅ **Cost Optimization** - Resource scheduling, auto-shutdown
- ✅ **Complete CI/CD** - GitHub Actions automation
- ✅ **Infrastructure as Code** - Terraform + K8s manifests
- ✅ **Self-Hosted Runners** - GitHub runners with health monitoring
- ✅ **Policy Governance** - Automated compliance and cost controls
- ✅ **Production Ready** - Reliable service startup and cleanup
- ✅ **Session Manager** - Secure browser-based terminal access
- ✅ **Unified Key Management** - Consistent SSH keys across all instances
- ✅ **Progressive Delivery** - Argo Rollouts with canary and blue/green deployments
- ✅ **Service Mesh Integration** - Istio for advanced traffic management
- ✅ **Kubernetes Secrets** - Secure credential management

## 📁 Clean Repository Structure

```
├── .github/workflows/           # 🔥 CLEANED: 3 Core Workflows Only
│   ├── core-infrastructure.yml  # Infrastructure management
│   ├── core-deployment.yml      # Application deployment  
│   └── core-operations.yml      # Monitoring & operations
├── docs/                        # 📚 Documentation
│   ├── architecture/            # Architecture documentation
│   ├── deployment/              # Deployment guides
│   ├── guides/                  # How-to guides
│   ├── kubernetes/              # Kubernetes documentation
│   ├── operations/              # Operations guides
│   └── README.md                # Documentation index
├── infra/                       # Infrastructure as Code
│   ├── modules/                 # Reusable modules
│   │   ├── vpc/                 # Multi-network VPC module
│   │   ├── k3s/                 # K8s cluster module
│   │   ├── rds/                 # Database module
│   │   └── monitoring/          # Monitoring module
│   ├── environments/            # Environment configs
│   │   ├── dev.tfvars          # Dev environment
│   │   ├── test.tfvars         # Test environment
│   │   ├── prod.tfvars         # Prod environment
│   │   ├── monitoring.tfvars   # Monitoring environment
│   │   └── network-architecture.tfvars  # 🆕 Network design
│   └── backend-configs/         # Terraform state
├── kubernetes-manifests/        # Kubernetes manifests
│   ├── base/                    # Base resources
│   ├── components/              # Reusable components
│   │   ├── health-api/         # Health API components
│   │   ├── monitoring/         # Monitoring components
│   │   └── networking/         # Network components
│   └── environments/           # Environment-specific configs
│       ├── dev/                # Development environment
│       ├── test/               # Test environment
│       └── prod/               # Production environment
└── scripts/                     # Automation scripts
    ├── k8s-health-check.sh     # Health monitoring
    ├── k8s-auto-scale.sh       # Auto-scaling
    └── setup-kubeconfig.sh     # Cluster connection
```

## Related Repositories

- [Health API](https://github.com/arunprabus/health-api): Backend API code
- [Health Frontend](https://github.com/arunprabus/health-dash): Frontend application code

## Documentation

For detailed documentation, please see the [docs](./docs) directory:

- [Architecture](./docs/architecture/) - Architecture design and changes
- [Deployment](./docs/deployment/) - Deployment guides and GitOps setup
- [Kubernetes](./docs/kubernetes/) - Kubernetes configuration and setup
- [Operations](./docs/operations/) - Operations and maintenance guides
- [Guides](./docs/guides/) - Quick start and testing guides

## Infrastructure Deployment

The infrastructure code manages the following resources:

- **VPC and networking** (isolated per environment)
- **K8s clusters** on EC2 (cost-effective alternative to EKS)
- **RDS database instances** with automated monitoring
- **Multi-environment setup** (dev/test/prod namespaces)
- **Auto-scaling** (HPA + resource scheduling)
- **Monitoring stack** (Prometheus + Grafana)
- **Cost optimization** (automated cleanup + scheduling)

## Deployment Strategy

### Infrastructure

The infrastructure is deployed using the GitHub Actions workflow in `.github/workflows/core-infrastructure.yml`. This creates the base infrastructure for each environment (development, test, production).

### Applications

Application deployments are handled through the following process:

1. Code is pushed to the application repositories (HealthApi or HealthFrontend)
2. The `.github/workflows/core-deployment.yml` workflow is triggered
3. The workflow builds the application and pushes it to the container registry
4. Argo Rollouts manages the deployment with advanced strategies

### Progressive Delivery with Argo Rollouts

We use Argo Rollouts for advanced deployment strategies:

1. **Canary Deployments**: Gradually shift traffic to the new version
2. **Blue/Green Deployments**: Switch traffic all at once after validation
3. **Traffic Management**: Integration with Istio service mesh

For more details, see [Argo Rollouts Documentation](docs/ARGO-ROLLOUTS.md)

## Getting Started

For quick setup instructions, see the [Quick Setup Guide](docs/guides/QUICK-SETUP.md).

### Prerequisites

- AWS CLI configured with appropriate credentials
- Terraform CLI (v1.6.0 or later)
- kubectl

### Deploying Infrastructure

You can deploy the infrastructure using the GitHub Actions workflow or manually:

```bash
cd infra
terraform init \
  -backend-config="bucket=your-terraform-state-bucket" \
  -backend-config="key=health-app-dev.tfstate" \
  -backend-config="region=ap-south-1"
terraform apply -var-file="environments/dev.tfvars"
```

## Network Architecture

For details on the three-tier network architecture, see [Architecture Changes](docs/architecture/ARCHITECTURE-CHANGES.md).

## Cost Optimization

This project is designed to run entirely within the AWS Free Tier. For details on cost optimization strategies, see [Cost Optimization](docs/COST-OPTIMIZATION.md).

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.