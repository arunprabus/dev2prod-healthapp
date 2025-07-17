# GitHub Secrets Management

This document explains how to manage GitHub secrets for the Health App infrastructure repository.

## Overview

GitHub secrets are used to store sensitive information like:
- AWS credentials
- SSH keys
- Kubeconfig files
- API keys
- Database credentials

This repository provides multiple ways to manage these secrets:

1. **GitHub Actions Workflow**: Automated secret management through the UI
2. **Bash Script**: For Linux/macOS users
3. **PowerShell Script**: For Windows users
4. **Batch Script**: For basic Windows command prompt

## Using the GitHub Actions Workflow

The easiest way to manage secrets is through the GitHub Actions workflow:

1. Go to **Actions** → **Update GitHub Secrets**
2. Click **Run workflow**
3. Select the action you want to perform:
   - `list`: List all secrets
   - `update`: Update a secret with a direct value
   - `update-file`: Update a secret from a file
   - `update-kubeconfig`: Update kubeconfig secret for an environment
   - `update-ssh-key`: Update SSH_PUBLIC_KEY and SSH_PRIVATE_KEY
   - `update-aws-creds`: Update AWS credentials from environment variables
4. Fill in the required parameters
5. Click **Run workflow**

### Examples

#### Listing all secrets

- Action: `list`
- No other parameters needed

#### Updating a kubeconfig secret

- Action: `update-kubeconfig`
- Environment: `dev`
- Kubeconfig file path: `kubeconfig-lower.yaml`

#### Updating SSH keys

- Action: `update-ssh-key`
- No other parameters needed (uses ~/.ssh/k3s-key)

## Using the Scripts Directly

### Bash Script (Linux/macOS)

```bash
# List all secrets
./scripts/update-github-secrets.sh list

# Update a secret
./scripts/update-github-secrets.sh update SECRET_NAME "secret-value"

# Update a secret from a file
./scripts/update-github-secrets.sh update-file SECRET_NAME path/to/file.txt

# Update kubeconfig for an environment
./scripts/update-github-secrets.sh update-kubeconfig dev kubeconfig-lower.yaml

# Update SSH keys
./scripts/update-github-secrets.sh update-ssh-key

# Update AWS credentials
./scripts/update-github-secrets.sh update-aws-creds
```

### PowerShell Script (Windows)

```powershell
# List all secrets
.\scripts\update-github-secrets.ps1 -Action list

# Update a secret
.\scripts\update-github-secrets.ps1 -Action update -SecretName SECRET_NAME -SecretValue "secret-value"

# Update a secret from a file
.\scripts\update-github-secrets.ps1 -Action update-file -SecretName SECRET_NAME -FilePath path\to\file.txt

# Update kubeconfig for an environment
.\scripts\update-github-secrets.ps1 -Action update-kubeconfig -SecretName dev -FilePath kubeconfig-lower.yaml

# Update SSH keys
.\scripts\update-github-secrets.ps1 -Action update-ssh-key

# Update AWS credentials
.\scripts\update-github-secrets.ps1 -Action update-aws-creds
```

### Batch Script (Windows Command Prompt)

```batch
:: List all secrets
scripts\update-github-secrets.bat list

:: Update a secret
scripts\update-github-secrets.bat update SECRET_NAME "secret-value"

:: Update a secret from a file
scripts\update-github-secrets.bat update-file SECRET_NAME path\to\file.txt

:: Update kubeconfig for an environment
scripts\update-github-secrets.bat update-kubeconfig dev kubeconfig-lower.yaml

:: Update SSH keys
scripts\update-github-secrets.bat update-ssh-key

:: Update AWS credentials
scripts\update-github-secrets.bat update-aws-creds
```

## GitHub Token Requirements

To manage secrets, you need a GitHub token with the appropriate permissions:

- For personal repositories: A personal access token with `repo` scope
- For organization repositories: A personal access token with `repo` and `admin:org` scopes

You can set the token in one of these ways:

1. Set the `GITHUB_TOKEN` environment variable
2. Pass it directly to the script (not recommended for security reasons)

## Kubeconfig Management

The kubeconfig secrets are used by GitHub Actions workflows to connect to your Kubernetes clusters. Each environment has its own kubeconfig secret:

- `KUBECONFIG_DEV`: For the development environment
- `KUBECONFIG_TEST`: For the test environment
- `KUBECONFIG_PROD`: For the production environment
- `KUBECONFIG_MONITORING`: For the monitoring environment

When updating these secrets, make sure the kubeconfig file points to the correct cluster IP address.

## SSH Key Management

The SSH keys are used to connect to the EC2 instances running the Kubernetes clusters. The following secrets are used:

- `SSH_PRIVATE_KEY`: The private SSH key
- `SSH_PUBLIC_KEY`: The public SSH key

These keys should be generated with:

```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/k3s-key -N "" -C "k3s-cluster-access"
```

## AWS Credentials Management

The AWS credentials are used to authenticate with AWS services. The following secrets are used:

- `AWS_ACCESS_KEY_ID`: The AWS access key ID
- `AWS_SECRET_ACCESS_KEY`: The AWS secret access key

These credentials should have the appropriate permissions to manage the resources in your AWS account.

## Troubleshooting

### Permission Denied

If you get a "Permission denied" error when running the script, make sure the script is executable:

```bash
chmod +x scripts/update-github-secrets.sh
```

### Invalid Token

If you get an "Invalid token" error, make sure your GitHub token has the appropriate permissions and hasn't expired.

### File Not Found

If you get a "File not found" error, make sure the file path is correct and the file exists.

### Python Dependencies

The script requires Python 3 and the PyNaCl library. If you get an error about missing dependencies, install them:

```bash
pip3 install PyNaCl
```

## Best Practices

1. **Rotate secrets regularly**: Update your secrets periodically for better security
2. **Use environment-specific secrets**: Keep secrets separate for different environments
3. **Limit access**: Only give access to secrets to those who need it
4. **Audit usage**: Regularly review who has access to your secrets
5. **Use least privilege**: Give secrets the minimum permissions needed