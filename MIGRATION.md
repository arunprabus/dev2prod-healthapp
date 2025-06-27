# Application Migration Guide

## Overview

The Health App codebase has been restructured to separate application code from infrastructure code. This document provides guidance on migrating and working with the new repository structure.

## Repository Structure Changes

### Before

A single repository contained both application and infrastructure code:

```
/
├── frontend/          # Frontend application code
├── k8s/               # Kubernetes manifests
├── infra/             # Infrastructure code
├── scripts/           # Utility scripts
└── docker-compose.yml # Local development setup
```

### After

The codebase is now split into multiple repositories:

1. **Infrastructure Repository** (this repo):
   ```
   /
   ├── infra/           # Infrastructure as Code (Terraform)
   │   ├── modules/     # Reusable Terraform modules
   │   └── environments/ # Environment configurations
   ├── .github/workflows/ # CI/CD pipelines
   └── scripts/         # Infrastructure utility scripts
   ```

2. **HealthApi Repository**:
   ```
   /
   ├── src/             # API source code
   ├── k8s/             # Kubernetes manifests for API
   ├── Dockerfile       # Container definition
   └── package.json     # Dependencies
   ```

3. **Frontend Repository**:
   ```
   /
   ├── src/             # Frontend source code
   ├── public/          # Static assets
   ├── k8s/             # Kubernetes manifests for frontend
   ├── Dockerfile       # Container definition
   └── package.json     # Dependencies
   ```

## Deployment Process

The deployment process now follows these steps:

1. **Infrastructure Deployment**:
   - Changes to the infrastructure code trigger the `infra-deploy.yml` workflow
   - This sets up or updates the AWS infrastructure (VPC, EKS, RDS, etc.)

2. **Application Deployment**:
   - Changes to application code in their respective repositories trigger builds
   - Docker images are built and pushed to the container registry
   - ArgoCD detects the changes and deploys to the appropriate environment

## Environment Targeting

The deployment targets different environments based on branch patterns:

| Branch   | Environment | Description                  |
|----------|-------------|------------------------------|
| `develop`| dev         | Development environment      |
| `staging`| test        | Testing/QA environment       |
| `main`   | prod        | Production environment       |

## Migration Steps for Developers

1. Clone the relevant repositories:
   ```bash
   git clone https://github.com/your-organization/health-app-infra.git
   git clone https://github.com/your-organization/health-api.git
   git clone https://github.com/your-organization/health-frontend.git
   ```

2. Update your local development workflow:
   - Use the application repositories for application code changes
   - Use the infrastructure repository for infrastructure changes

3. Update CI/CD understanding:
   - Application CI/CD is now separate from infrastructure CI/CD
   - Infrastructure changes go through a different approval process

## Benefits of the New Structure

1. **Clear Separation of Concerns**:
   - Application developers focus on application code
   - Infrastructure team focuses on infrastructure code

2. **Independent Scaling**:
   - Application code can change frequently without affecting infrastructure
   - Infrastructure can be updated without redeploying applications

3. **Better Security**:
   - More granular access control
   - Reduced risk of accidental infrastructure changes

4. **Simplified CI/CD**:
   - More targeted pipelines
   - Faster builds and deployments

## Contact

For questions about this migration, contact the DevOps team at devops@example.com.
