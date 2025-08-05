#!/bin/bash

# Complete AWS resource destruction across all regions

REGIONS="ap-south-1 ap-northeast-3 ap-northeast-2 ap-southeast-1 ap-southeast-2 ap-northeast-1 ca-central-1 eu-central-1 eu-west-1 eu-west-2 eu-west-3 eu-north-1 sa-east-1 us-west-1 us-east-1 us-east-2 us-west-2"

for region in $REGIONS; do
    echo "🧨 Nuking region: $region"
    
    # Terminate EC2 instances
    for id in $(aws ec2 describe-instances --region $region --query 'Reservations[].Instances[?State.Name!=`terminated`].InstanceId' --output text 2>/dev/null); do
        aws ec2 terminate-instances --region $region --instance-ids $id || true
    done
    
    # Delete Auto Scaling Groups
    for asg in $(aws autoscaling describe-auto-scaling-groups --region $region --query 'AutoScalingGroups[].AutoScalingGroupName' --output text 2>/dev/null); do
        aws autoscaling delete-auto-scaling-group --region $region --auto-scaling-group-name $asg --force-delete || true
    done
    
    # Release Elastic IPs
    for eip in $(aws ec2 describe-addresses --region $region --query 'Addresses[].AllocationId' --output text 2>/dev/null); do
        aws ec2 release-address --region $region --allocation-id $eip || true
    done
    
    # Delete NAT Gateways
    for nat in $(aws ec2 describe-nat-gateways --region $region --query 'NatGateways[].NatGatewayId' --output text 2>/dev/null); do
        aws ec2 delete-nat-gateway --region $region --nat-gateway-id $nat || true
    done
    
    # Delete VPC Endpoints
    for vpce in $(aws ec2 describe-vpc-endpoints --region $region --query 'VpcEndpoints[].VpcEndpointId' --output text 2>/dev/null); do
        aws ec2 delete-vpc-endpoint --region $region --vpc-endpoint-id $vpce || true
    done
    
    # Delete VPC Peering Connections
    for peer in $(aws ec2 describe-vpc-peering-connections --region $region --query 'VpcPeeringConnections[].VpcPeeringConnectionId' --output text 2>/dev/null); do
        aws ec2 delete-vpc-peering-connection --region $region --vpc-peering-connection-id $peer || true
    done
    
    # Detach and Delete Internet Gateways
    for igw in $(aws ec2 describe-internet-gateways --region $region --query 'InternetGateways[?Attachments[0].VpcId!=null].[InternetGatewayId,Attachments[0].VpcId]' --output text 2>/dev/null); do
        igw_id=$(echo $igw | awk '{print $1}')
        vpc_id=$(echo $igw | awk '{print $2}')
        aws ec2 detach-internet-gateway --region $region --internet-gateway-id $igw_id --vpc-id $vpc_id || true
        aws ec2 delete-internet-gateway --region $region --internet-gateway-id $igw_id || true
    done
    
    # Delete Route Tables (non-main)
    for rt in $(aws ec2 describe-route-tables --region $region --query 'RouteTables[?Associations[0].Main!=`true`].RouteTableId' --output text 2>/dev/null); do
        aws ec2 delete-route-table --region $region --route-table-id $rt || true
    done
    
    # Delete Security Groups (non-default)
    for sg in $(aws ec2 describe-security-groups --region $region --query 'SecurityGroups[?GroupName!=`default`].GroupId' --output text 2>/dev/null); do
        aws ec2 delete-security-group --region $region --group-id $sg || true
    done
    
    # Delete Network ACLs (non-default)
    for acl in $(aws ec2 describe-network-acls --region $region --query 'NetworkAcls[?IsDefault!=`true`].NetworkAclId' --output text 2>/dev/null); do
        aws ec2 delete-network-acl --region $region --network-acl-id $acl || true
    done
    
    # Delete Network Interfaces
    for eni in $(aws ec2 describe-network-interfaces --region $region --query 'NetworkInterfaces[?Status==`available`].NetworkInterfaceId' --output text 2>/dev/null); do
        aws ec2 delete-network-interface --region $region --network-interface-id $eni || true
    done
    
    # Delete Subnets
    for subnet in $(aws ec2 describe-subnets --region $region --query 'Subnets[].SubnetId' --output text 2>/dev/null); do
        aws ec2 delete-subnet --region $region --subnet-id $subnet || true
    done
    
    # Delete Volumes
    for vol in $(aws ec2 describe-volumes --region $region --query 'Volumes[?State==`available`].VolumeId' --output text 2>/dev/null); do
        aws ec2 delete-volume --region $region --volume-id $vol || true
    done
    
    # Delete VPCs
    sleep 30
    for vpc in $(aws ec2 describe-vpcs --region $region --query 'Vpcs[?IsDefault==`false`].VpcId' --output text 2>/dev/null); do
        aws ec2 delete-vpc --region $region --vpc-id $vpc || true
    done
    
    echo "✅ Region $region nuked"
done

echo "🧨 Complete AWS nuke finished"