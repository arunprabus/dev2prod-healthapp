# 🖥️ Batch Scripts & Automation

This folder contains Windows batch scripts and PowerShell automation tools.

## 📁 Script Files

### 💰 Cost Management
- [aws-audit.bat](aws-audit.bat) - Complete AWS resource audit
- [aws-cost-audit.ps1](aws-cost-audit.ps1) - PowerShell cost analysis
- [test-passrole.bat](test-passrole.bat) - IAM PassRole permission test

### 🗄️ Database Management
- [backup-and-destroy-rds.bat](backup-and-destroy-rds.bat) - RDS backup & cleanup
- [s3-db-backup.bat](s3-db-backup.bat) - S3 database export

## 🔧 Usage

### Run Batch Scripts
```cmd
# Windows Command Prompt
cd batch-scripts
aws-audit.bat
```

### Run PowerShell Scripts
```powershell
# PowerShell
cd batch-scripts
powershell -ExecutionPolicy Bypass -File aws-cost-audit.ps1
```

## 📋 Prerequisites
- AWS CLI configured
- Appropriate IAM permissions
- PowerShell (for .ps1 files)