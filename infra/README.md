# Infrastructure Management

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