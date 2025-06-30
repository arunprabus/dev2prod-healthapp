@echo off
echo === AWS COST AUDIT REPORT ===
echo.

echo VPC RESOURCES:
echo NAT Gateways:
aws ec2 describe-nat-gateways --query "NatGateways[?State=='available'].[NatGatewayId,State,VpcId]" --output table
echo.

echo Elastic IPs (Unattached):
aws ec2 describe-addresses --query "Addresses[?AssociationId==null].[PublicIp,AllocationId]" --output table
echo.

echo RDS RESOURCES:
echo Running DB Instances:
aws rds describe-db-instances --query "DBInstances[?DBInstanceStatus=='available'].[DBInstanceIdentifier,DBInstanceClass,Engine]" --output table
echo.

echo Manual DB Snapshots:
aws rds describe-db-snapshots --snapshot-type manual --query "DBSnapshots[?Status=='available'].[DBSnapshotIdentifier,DBInstanceIdentifier]" --output table
echo.

echo EC2 RESOURCES:
echo Running Instances:
aws ec2 describe-instances --query "Reservations[].Instances[?State.Name=='running'].[InstanceId,InstanceType,State.Name]" --output table
echo.

echo EBS Volumes:
aws ec2 describe-volumes --query "Volumes[?State=='available'].[VolumeId,Size,VolumeType]" --output table
echo.

echo S3 BUCKETS:
aws s3 ls
echo.

echo === CLEANUP COMMANDS ===
echo Stop RDS: aws rds stop-db-instance --db-instance-identifier DB-ID
echo Delete NAT: aws ec2 delete-nat-gateway --nat-gateway-id NAT-ID
echo Release IP: aws ec2 release-address --allocation-id ALLOC-ID