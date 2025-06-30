#!/usr/bin/env powershell
# AWS Cost Audit Script - Check all resources generating charges

Write-Host "=== AWS COST AUDIT REPORT ===" -ForegroundColor Cyan
Write-Host "Checking resources that may be generating costs..." -ForegroundColor Yellow

# VPC Resources (Main cost driver)
Write-Host "`n🔵 VPC RESOURCES:" -ForegroundColor Blue
Write-Host "NAT Gateways:"
aws ec2 describe-nat-gateways --query 'NatGateways[?State==`available`].[NatGatewayId,State,VpcId,SubnetId]' --output table

Write-Host "`nElastic IPs (Unattached = Charged):"
aws ec2 describe-addresses --query 'Addresses[?AssociationId==null].[PublicIp,AllocationId,Domain]' --output table

Write-Host "`nVPC Endpoints:"
aws ec2 describe-vpc-endpoints --query 'VpcEndpoints[?State==`available`].[VpcEndpointId,ServiceName,VpcId]' --output table

# RDS Resources
Write-Host "`n🟧 RDS RESOURCES:" -ForegroundColor Red
Write-Host "Running DB Instances:"
aws rds describe-db-instances --query 'DBInstances[?DBInstanceStatus==`available`].[DBInstanceIdentifier,DBInstanceClass,Engine,DBInstanceStatus]' --output table

Write-Host "`nDB Snapshots (Manual = Charged):"
aws rds describe-db-snapshots --snapshot-type manual --query 'DBSnapshots[?Status==`available`].[DBSnapshotIdentifier,DBInstanceIdentifier,SnapshotCreateTime]' --output table

# EC2 Resources
Write-Host "`n🟨 EC2 RESOURCES:" -ForegroundColor Yellow
Write-Host "Running Instances:"
aws ec2 describe-instances --query 'Reservations[].Instances[?State.Name==`running`].[InstanceId,InstanceType,State.Name,LaunchTime]' --output table

Write-Host "`nEBS Volumes:"
aws ec2 describe-volumes --query 'Volumes[?State==`available`].[VolumeId,Size,VolumeType,State]' --output table

# S3 Resources
Write-Host "`n🟩 S3 RESOURCES:" -ForegroundColor Green
Write-Host "S3 Buckets:"
aws s3 ls

# Lambda Functions
Write-Host "`n🟪 LAMBDA FUNCTIONS:" -ForegroundColor Magenta
aws lambda list-functions --query 'Functions[?LastModified>=`2024-01-01`].[FunctionName,Runtime,LastModified]' --output table

# Cost Explorer - Recent charges
Write-Host "`n💰 RECENT COSTS:" -ForegroundColor Cyan
$endDate = (Get-Date).ToString("yyyy-MM-dd")
$startDate = (Get-Date).AddDays(-30).ToString("yyyy-MM-dd")

aws ce get-cost-and-usage --time-period Start=$startDate,End=$endDate --granularity MONTHLY --metrics BlendedCost --group-by Type=DIMENSION,Key=SERVICE --query "ResultsByTime[0].Groups[?Metrics.BlendedCost.Amount>\`0.01\`].[Keys[0],Metrics.BlendedCost.Amount]" --output table

Write-Host "`n=== CLEANUP COMMANDS ===" -ForegroundColor Red
Write-Host "# Stop RDS instances:"
Write-Host "aws rds stop-db-instance --db-instance-identifier <DB-ID>"
Write-Host "`n# Delete NAT Gateway:"
Write-Host "aws ec2 delete-nat-gateway --nat-gateway-id <NAT-ID>"
Write-Host "`n# Release Elastic IP:"
Write-Host "aws ec2 release-address --allocation-id <ALLOC-ID>"
Write-Host "`n# Delete manual snapshots:"
Write-Host "aws rds delete-db-snapshot --db-snapshot-identifier <SNAPSHOT-ID>"