#!/bin/bash

echo "🔍 Debugging Lower Environment Clusters..."

echo "All instances with 'lower' tag:"
aws ec2 describe-instances \
  --filters "Name=tag:Environment,Values=lower" "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].{Name:Tags[?Key==`Name`].Value|[0],IP:PublicIpAddress,State:State.Name}' \
  --output table

echo ""
echo "Looking for dev cluster specifically:"
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=health-app-lower-dev" \
  --query 'Reservations[].Instances[].{Name:Tags[?Key==`Name`].Value|[0],IP:PublicIpAddress,State:State.Name}' \
  --output table

echo ""
echo "Looking for test cluster specifically:"
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=health-app-lower-test" \
  --query 'Reservations[].Instances[].{Name:Tags[?Key==`Name`].Value|[0],IP:PublicIpAddress,State:State.Name}' \
  --output table

echo ""
echo "All instances in lower VPC:"
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=health-app-lower-vpc" --query 'Vpcs[0].VpcId' --output text)
aws ec2 describe-instances \
  --filters "Name=vpc-id,Values=$VPC_ID" "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].{Name:Tags[?Key==`Name`].Value|[0],IP:PublicIpAddress,PrivateIP:PrivateIpAddress}' \
  --output table