# Kubeconfig S3 Management

## Overview

The infrastructure workflow now automatically stores kubeconfig files to S3 for all environments, providing centralized access and eliminating the need for manual kubeconfig generation.

## S3 Storage Structure

```
s3://health-app-terraform-state/kubeconfig/
├── lower-network.yaml      # Lower network (dev/test shared)
├── higher-network.yaml     # Higher network (prod)
├── monitoring-network.yaml # Monitoring network
├── dev-network.yaml        # Dev environment copy
├── test-network.yaml       # Test environment copy
└── prod-network.yaml       # Prod environment copy
```

## Automatic Workflow Integration

### Infrastructure Deployment
When deploying infrastructure:
1. Terraform creates K3s cluster
2. Workflow waits for cluster readiness
3. SSH connection retrieves kubeconfig
4. Kubeconfig is processed and uploaded to S3
5. Environment-specific copies are created

### Application Deployment
When deploying applications:
1. Workflow determines target environment
2. Downloads appropriate kubeconfig from S3
3. Falls back to dynamic generation if S3 fails
4. Connects to correct cluster automatically

## Environment Mapping

| Environment | Primary S3 Path | Fallback S3 Path | Network |
|-------------|----------------|------------------|---------|
| dev | `kubeconfig/dev-network.yaml` | `kubeconfig/lower-network.yaml` | Lower |
| test | `kubeconfig/test-network.yaml` | `kubeconfig/lower-network.yaml` | Lower |
| prod | `kubeconfig/prod-network.yaml` | `kubeconfig/higher-network.yaml` | Higher |
| monitoring | `kubeconfig/monitoring-network.yaml` | - | Monitoring |

## Manual Management

Use the provided script for manual operations:

```bash
# List all kubeconfig files
./scripts/manage-kubeconfig-s3.sh list

# Download kubeconfig for dev environment
./scripts/manage-kubeconfig-s3.sh download dev

# Upload custom kubeconfig
./scripts/manage-kubeconfig-s3.sh upload dev ~/.kube/my-config

# Sync from running cluster
./scripts/manage-kubeconfig-s3.sh sync dev 1.2.3.4

# Delete kubeconfig
./scripts/manage-kubeconfig-s3.sh delete dev
```

## Benefits

✅ **Centralized Storage**: All kubeconfig files in one S3 location
✅ **Automatic Updates**: Infrastructure changes update S3 automatically
✅ **Environment Isolation**: Separate configs for each environment
✅ **Fallback Support**: Multiple paths tried for reliability
✅ **Zero Manual Setup**: Complete automation from infrastructure to deployment
✅ **Cleanup Integration**: S3 files removed when infrastructure destroyed

## Security

- Kubeconfig files stored in private S3 bucket
- Access controlled via AWS IAM
- Files encrypted at rest in S3
- No sensitive data exposed in workflow logs
- SSH keys used securely for cluster access

## Troubleshooting

### Kubeconfig Not Found
```bash
# Check S3 contents
aws s3 ls s3://health-app-terraform-state/kubeconfig/

# Re-run infrastructure deployment to regenerate
Actions → Core Infrastructure → deploy
```

### Connection Issues
```bash
# Download and test kubeconfig
./scripts/manage-kubeconfig-s3.sh download dev ~/.kube/test-config
export KUBECONFIG=~/.kube/test-config
kubectl cluster-info
```

### Manual Sync
```bash
# Get cluster IP from AWS console or Terraform output
CLUSTER_IP="1.2.3.4"
./scripts/manage-kubeconfig-s3.sh sync dev $CLUSTER_IP
```