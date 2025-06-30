# GitHub Setup Guide

## Required GitHub Secrets

### Repository Secrets (Settings → Secrets and variables → Actions)

```bash
# AWS Credentials
AWS_ACCESS_KEY_ID=AKIA...
AWS_SECRET_ACCESS_KEY=...

# Terraform State Backend
TF_STATE_BUCKET=your-terraform-state-bucket-name
```

## AWS Setup Steps

### 1. Create S3 Bucket for Terraform State
```bash
aws s3 mb s3://health-app-terraform-state-bucket
aws s3api put-bucket-versioning --bucket health-app-terraform-state-bucket --versioning-configuration Status=Enabled
```

### 2. Create DynamoDB Table for State Locking
```bash
aws dynamodb create-table \
  --table-name terraform-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST
```

### 3. Create IAM User for GitHub Actions
```bash
# Create user
aws iam create-user --user-name github-actions-terraform

# Attach policy (use existing or create custom)
aws iam attach-user-policy --user-name github-actions-terraform --policy-arn arn:aws:iam::aws:policy/AdministratorAccess

# Create access keys
aws iam create-access-key --user-name github-actions-terraform
```

## GitHub Secrets Configuration

| Secret Name | Value | Description |
|-------------|-------|-------------|
| `AWS_ACCESS_KEY_ID` | `AKIA...` | AWS Access Key ID |
| `AWS_SECRET_ACCESS_KEY` | `...` | AWS Secret Access Key |
| `TF_STATE_BUCKET` | `health-app-terraform-state-bucket` | S3 bucket for Terraform state |

## Environment Configuration (Optional)

If using GitHub Environments for approval workflows:

### Create Environments
1. Go to Settings → Environments
2. Create: `dev`, `test`, `prod`
3. Add protection rules for `prod` (require approval)

## Backend Configuration

Update `infra/backend.tf`:
```hcl
terraform {
  backend "s3" {
    bucket         = "health-app-terraform-state-bucket"
    key            = "health-app-{environment}.tfstate"
    region         = "ap-south-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}
```

## Verification

Test the setup:
```bash
# Local test
make infra-plan ENV=dev

# GitHub Actions test
# Go to Actions → Infrastructure Deployment → Run workflow
```