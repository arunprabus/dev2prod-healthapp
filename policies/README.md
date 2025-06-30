# 🔐 IAM Policies & Permissions

This folder contains AWS IAM policies and permission configurations.

## 📁 Policy Files

### 🗄️ Database Policies
- [rds-snapshot-permissions.json](rds-snapshot-permissions.json) - RDS snapshot management
- [s3-restore-iam-policy.json](s3-restore-iam-policy.json) - S3 backup access
- [s3-restore-iam-role.json](s3-restore-iam-role.json) - RDS S3 export role

### 🧹 Resource Management
- [aws-cleanup-policy.json](aws-cleanup-policy.json) - Resource cleanup permissions
- [aws-iam-policy.json](aws-iam-policy.json) - General IAM policy template

## 🔧 Usage

### Apply Policy to User
```bash
aws iam put-user-policy --user-name your-user --policy-name PolicyName --policy-document file://policy-file.json
```

### Apply Policy to Group
```bash
aws iam put-group-policy --group-name your-group --policy-name PolicyName --policy-document file://policy-file.json
```

### Create IAM Role
```bash
aws iam create-role --role-name your-role --assume-role-policy-document file://role-file.json
```