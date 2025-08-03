#!/bin/bash

# EC2 Auto-scaling Script for Health App
set -e

ACTION=${1:-"status"}  # status, scale-out, scale-in, schedule
ENVIRONMENT=${2:-"dev"}
APP_NAME=${3:-"health-api"}

log() {
    echo "$(date): $1"
}

get_instances() {
    aws ec2 describe-instances \
        --filters "Name=tag:Name,Values=health-app-${APP_NAME}-${ENVIRONMENT}*" \
                 "Name=instance-state-name,Values=running,stopped" \
        --query "Reservations[].Instances[].[InstanceId,State.Name,PublicIpAddress,Tags[?Key=='Name'].Value|[0]]" \
        --output table
}

get_running_count() {
    aws ec2 describe-instances \
        --filters "Name=tag:Name,Values=health-app-${APP_NAME}-${ENVIRONMENT}*" \
                 "Name=instance-state-name,Values=running" \
        --query "length(Reservations[].Instances[])" \
        --output text
}

create_instance() {
    local instance_number=$1
    local instance_name="health-app-${APP_NAME}-${ENVIRONMENT}-${instance_number}"
    
    log "🚀 Creating new instance: $instance_name"
    
    # Get latest Ubuntu AMI
    AMI_ID=$(aws ec2 describe-images \
        --owners 099720109477 \
        --filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*" \
        --query "Images | sort_by(@, &CreationDate) | [-1].ImageId" \
        --output text)
    
    # Get security group
    SG_ID=$(aws ec2 describe-security-groups \
        --filters "Name=group-name,Values=health-app-${ENVIRONMENT}-sg" \
        --query "SecurityGroups[0].GroupId" \
        --output text)
    
    if [ "$SG_ID" = "None" ]; then
        log "❌ Security group not found. Run infrastructure deployment first."
        exit 1
    fi
    
    # Launch instance
    INSTANCE_ID=$(aws ec2 run-instances \
        --image-id $AMI_ID \
        --count 1 \
        --instance-type t2.micro \
        --key-name "health-app-${ENVIRONMENT}-key" \
        --security-group-ids $SG_ID \
        --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$instance_name},{Key=Environment,Value=$ENVIRONMENT},{Key=Project,Value=health-app},{Key=AutoScale,Value=true}]" \
        --user-data file://scripts/ec2-user-data.sh \
        --query "Instances[0].InstanceId" \
        --output text)
    
    log "✅ Created instance: $INSTANCE_ID"
    log "⏳ Waiting for instance to be running..."
    
    aws ec2 wait instance-running --instance-ids $INSTANCE_ID
    
    # Get public IP
    PUBLIC_IP=$(aws ec2 describe-instances \
        --instance-ids $INSTANCE_ID \
        --query "Reservations[0].Instances[0].PublicIpAddress" \
        --output text)
    
    log "🌐 Instance ready at: $PUBLIC_IP"
    echo "$INSTANCE_ID"
}

terminate_oldest_instance() {
    local instance_id=$(aws ec2 describe-instances \
        --filters "Name=tag:Name,Values=health-app-${APP_NAME}-${ENVIRONMENT}*" \
                 "Name=instance-state-name,Values=running" \
        --query "Reservations[].Instances[] | sort_by(@, &LaunchTime) | [0].InstanceId" \
        --output text)
    
    if [ "$instance_id" != "None" ] && [ -n "$instance_id" ]; then
        log "🛑 Terminating oldest instance: $instance_id"
        aws ec2 terminate-instances --instance-ids $instance_id
        log "✅ Instance $instance_id terminated"
    else
        log "⚠️ No instances to terminate"
    fi
}

scale_out() {
    local current_count=$(get_running_count)
    local max_instances=3
    
    if [ "$current_count" -ge "$max_instances" ]; then
        log "⚠️ Maximum instances ($max_instances) reached"
        return
    fi
    
    local next_number=$((current_count + 1))
    create_instance $next_number
}

scale_in() {
    local current_count=$(get_running_count)
    local min_instances=1
    
    if [ "$current_count" -le "$min_instances" ]; then
        log "⚠️ Minimum instances ($min_instances) reached"
        return
    fi
    
    terminate_oldest_instance
}

schedule_scaling() {
    local hour=$(date +%H)
    local current_count=$(get_running_count)
    
    # Business hours: 9 AM - 6 PM (scale out to 2 instances)
    if [[ "$hour" -ge 9 && "$hour" -lt 18 ]]; then
        if [ "$current_count" -lt 2 ]; then
            log "📈 Business hours - scaling out to 2 instances"
            scale_out
        fi
    # Off hours: scale in to 1 instance
    else
        if [ "$current_count" -gt 1 ]; then
            log "📉 Off hours - scaling in to 1 instance"
            scale_in
        fi
    fi
}

case "$ACTION" in
    "status")
        log "📊 Current EC2 instances for $APP_NAME in $ENVIRONMENT:"
        get_instances
        log "Running instances: $(get_running_count)"
        ;;
    "scale-out")
        scale_out
        ;;
    "scale-in")
        scale_in
        ;;
    "schedule")
        schedule_scaling
        ;;
    *)
        log "Usage: $0 {status|scale-out|scale-in|schedule} [environment] [app_name]"
        exit 1
        ;;
esac