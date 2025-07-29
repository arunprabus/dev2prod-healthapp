#!/bin/bash

echo "🚨 Emergency Infrastructure Diagnosis"
echo "======================================"

# Check AWS credentials
echo "🔐 AWS Identity:"
aws sts get-caller-identity || echo "❌ AWS credentials failed"

# Check instances status
echo -e "\n📊 Instance Status:"
aws ec2 describe-instances \
  --filters "Name=tag:Environment,Values=lower" \
  --query 'Reservations[].Instances[].[Tags[?Key==`Name`].Value|[0],InstanceId,State.Name,PublicIpAddress,PrivateIpAddress]' \
  --output table || echo "❌ Failed to get instances"

# Check security groups
echo -e "\n🔒 Security Groups:"
aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=*k3s*,*health-app*" \
  --query 'SecurityGroups[].[GroupName,GroupId,VpcId]' \
  --output table || echo "❌ Failed to get security groups"

# Test connectivity to clusters
echo -e "\n🌐 Connectivity Tests:"
CLUSTERS=("13.232.75.155" "13.127.158.59")

for IP in "${CLUSTERS[@]}"; do
  echo "Testing $IP:6443..."
  timeout 5 bash -c "</dev/tcp/$IP/6443" 2>/dev/null && echo "✅ $IP:6443 reachable" || echo "❌ $IP:6443 unreachable"
  
  echo "Testing $IP:22..."
  timeout 5 bash -c "</dev/tcp/$IP/22" 2>/dev/null && echo "✅ $IP:22 reachable" || echo "❌ $IP:22 unreachable"
done

# Check Parameter Store
echo -e "\n📋 Parameter Store Status:"
aws ssm get-parameters-by-path \
  --path "/dev/health-app" \
  --recursive \
  --query 'Parameters[].[Name,Value]' \
  --output table || echo "❌ Parameter Store access failed"

aws ssm get-parameters-by-path \
  --path "/test/health-app" \
  --recursive \
  --query 'Parameters[].[Name,Value]' \
  --output table || echo "❌ Parameter Store access failed"

# Check VPC and subnets
echo -e "\n🏗️ VPC Status:"
aws ec2 describe-vpcs \
  --filters "Name=tag:Name,Values=*health-app*" \
  --query 'Vpcs[].[VpcId,CidrBlock,State,Tags[?Key==`Name`].Value|[0]]' \
  --output table || echo "❌ VPC access failed"

# Check RDS
echo -e "\n🗄️ Database Status:"
aws rds describe-db-instances \
  --query 'DBInstances[].[DBInstanceIdentifier,DBInstanceStatus,Endpoint.Address,Engine]' \
  --output table || echo "❌ RDS access failed"

echo -e "\n🎯 Diagnosis Complete!"
echo "If all tests fail, your AWS session may be expired or infrastructure destroyed."