# Parameter Store Kubeconfig Integration

## Overview

This document explains how the Health App infrastructure uses AWS Systems Manager Parameter Store to manage Kubernetes cluster access credentials, solving the cluster connection issues in lower environments.

## Problem Solved

Previously, cluster connections were failing because:
- Kubeconfig files were only stored in S3
- SSH-based access was unreliable
- Token management was manual and error-prone

## Solution

The new Parameter Store integration provides:
- ✅ **Secure credential storage** using AWS SSM Parameter Store
- ✅ **Automatic token generation** during cluster setup
- ✅ **Centralized access management** for all environments
- ✅ **GitHub Actions integration** with fallback mechanisms
- ✅ **Easy cluster connection testing**

## Architecture

### Parameter Store Structure

```
/{environment}/health-app/kubeconfig/
├── server          # Kubernetes API server endpoint (String)
├── token           # Service account token (SecureString)
└── cluster-name    # Cluster name for reference (String)
```

### Components Updated

1. **Parameter Store Module** (`infra/modules/parameter-store/`)
   - Stores kubeconfig data securely
   - Manages IAM permissions for access

2. **K3s Module** (`infra/modules/k3s/`)
   - Automatically stores kubeconfig in Parameter Store during setup
   - Creates service accounts with proper RBAC

3. **Scripts** (`scripts/`)
   - `get-kubeconfig-from-parameter-store.sh` - Retrieve kubeconfig
   - `setup-parameter-store-kubeconfig.sh` - Setup Parameter Store data
   - `github-actions-kubeconfig.sh` - GitHub Actions integration

4. **GitHub Actions** (`.github/workflows/core-deployment.yml`)
   - Uses Parameter Store with fallback to GitHub secrets

## Usage

### 1. Setup Parameter Store for Existing Clusters

```bash
# For dev environment
./scripts/setup-parameter-store-kubeconfig.sh dev

# For test environment
./scripts/setup-parameter-store-kubeconfig.sh test
```

### 2. Retrieve Kubeconfig

```bash
# Get kubeconfig for dev environment
./scripts/get-kubeconfig-from-parameter-store.sh dev

# Get kubeconfig for test environment
./scripts/get-kubeconfig-from-parameter-store.sh test
```

### 3. Test Cluster Connection

```bash
# Test lower environment clusters
./scripts/test-lower-deployment.sh
```

## GitHub Actions Integration

The deployment workflow now:

1. **Tries Parameter Store first** for kubeconfig data
2. **Falls back to GitHub secrets** if Parameter Store is unavailable
3. **Creates kubeconfig dynamically** from retrieved parameters
4. **Tests connection** before proceeding with deployment

## Security Features

- **Encrypted tokens** stored as SecureString in Parameter Store
- **IAM-based access control** for parameter retrieval
- **Service account tokens** with limited permissions
- **Automatic token rotation** (24-hour duration)

## Troubleshooting

### Connection Failures

1. **Check Parameter Store data**:
   ```bash
   aws ssm get-parameters-by-path --path "/dev/health-app/kubeconfig/" --region ap-south-1
   ```

2. **Verify cluster is running**:
   ```bash
   aws ec2 describe-instances --filters "Name=tag:Name,Values=health-app-lower-dev" "Name=instance-state-name,Values=running"
   ```

3. **Re-setup Parameter Store**:
   ```bash
   ./scripts/setup-parameter-store-kubeconfig.sh dev
   ```

### Token Expiration

Service account tokens expire after 24 hours. To refresh:

```bash
./scripts/setup-parameter-store-kubeconfig.sh <environment>
```

## Benefits

1. **Reliability**: No more SSH connection failures
2. **Security**: Encrypted credential storage
3. **Automation**: Automatic setup during infrastructure deployment
4. **Flexibility**: Works with both GitHub Actions and local development
5. **Monitoring**: Easy to audit parameter access

## Next Steps

1. Deploy infrastructure with Parameter Store enabled
2. Run setup scripts for existing clusters
3. Test cluster connections
4. Update GitHub Actions workflows to use new integration

## Files Modified

- `infra/modules/parameter-store/main.tf` - Added kubeconfig storage
- `infra/modules/k3s/main.tf` - Added Parameter Store integration
- `infra/main.tf` - Enabled Parameter Store module
- `scripts/get-kubeconfig-from-parameter-store.sh` - New retrieval script
- `scripts/setup-parameter-store-kubeconfig.sh` - New setup script
- `scripts/test-lower-deployment.sh` - Updated to use Parameter Store
- `.github/workflows/core-deployment.yml` - Added Parameter Store support