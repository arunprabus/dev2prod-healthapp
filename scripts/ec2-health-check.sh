#!/bin/bash

# EC2 Health Check Script
set -e

ENVIRONMENT=${1:-"dev"}
APP_NAME=${2:-"health-api"}

log() {
    echo "$(date): $1"
}

check_instance_health() {
    local instance_id=$1
    local public_ip=$2
    local instance_name=$3
    
    log "🔍 Checking health for $instance_name ($instance_id)"
    
    # Check if instance is running
    local state=$(aws ec2 describe-instances \
        --instance-ids $instance_id \
        --query "Reservations[0].Instances[0].State.Name" \
        --output text)
    
    if [ "$state" != "running" ]; then
        log "❌ Instance $instance_id is $state"
        return 1
    fi
    
    # Check SSH connectivity
    if ! ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -i <(echo "$SSH_PRIVATE_KEY") ubuntu@$public_ip "echo 'SSH OK'" >/dev/null 2>&1; then
        log "❌ SSH connection failed for $instance_id"
        return 1
    fi
    
    # Check application health endpoint
    if curl -f --connect-timeout 10 http://$public_ip:8080/health >/dev/null 2>&1; then
        log "✅ Health endpoint OK for $instance_id"
    else
        log "⚠️ Health endpoint failed for $instance_id"
        
        # Try to restart the application
        log "🔄 Attempting to restart application..."
        ssh -o StrictHostKeyChecking=no -i <(echo "$SSH_PRIVATE_KEY") ubuntu@$public_ip "sudo docker restart $APP_NAME" || true
        
        sleep 10
        
        # Check again
        if curl -f --connect-timeout 10 http://$public_ip:8080/health >/dev/null 2>&1; then
            log "✅ Application restarted successfully"
        else
            log "❌ Application restart failed"
            return 1
        fi
    fi
    
    # Check system resources
    local cpu_usage=$(ssh -o StrictHostKeyChecking=no -i <(echo "$SSH_PRIVATE_KEY") ubuntu@$public_ip "top -bn1 | grep 'Cpu(s)' | awk '{print \$2}' | cut -d'%' -f1" 2>/dev/null || echo "unknown")
    local memory_usage=$(ssh -o StrictHostKeyChecking=no -i <(echo "$SSH_PRIVATE_KEY") ubuntu@$public_ip "free | grep Mem | awk '{printf \"%.1f\", \$3/\$2 * 100.0}'" 2>/dev/null || echo "unknown")
    local disk_usage=$(ssh -o StrictHostKeyChecking=no -i <(echo "$SSH_PRIVATE_KEY") ubuntu@$public_ip "df -h / | awk 'NR==2{print \$5}'" 2>/dev/null || echo "unknown")
    
    log "📊 System metrics for $instance_id:"
    log "   CPU: ${cpu_usage}%"
    log "   Memory: ${memory_usage}%"
    log "   Disk: ${disk_usage}"
    
    return 0
}

# Main health check
log "🏥 Starting health check for $APP_NAME in $ENVIRONMENT environment"

# Get all running instances
instances=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=health-app-${APP_NAME}-${ENVIRONMENT}*" \
             "Name=instance-state-name,Values=running" \
    --query "Reservations[].Instances[].[InstanceId,PublicIpAddress,Tags[?Key=='Name'].Value|[0]]" \
    --output text)

if [ -z "$instances" ]; then
    log "❌ No running instances found for $APP_NAME in $ENVIRONMENT"
    exit 1
fi

healthy_count=0
total_count=0

while IFS=$'\t' read -r instance_id public_ip instance_name; do
    if [ -n "$instance_id" ]; then
        total_count=$((total_count + 1))
        if check_instance_health "$instance_id" "$public_ip" "$instance_name"; then
            healthy_count=$((healthy_count + 1))
        fi
    fi
done <<< "$instances"

log "📊 Health check summary:"
log "   Total instances: $total_count"
log "   Healthy instances: $healthy_count"
log "   Unhealthy instances: $((total_count - healthy_count))"

if [ $healthy_count -eq $total_count ]; then
    log "✅ All instances are healthy"
    exit 0
elif [ $healthy_count -gt 0 ]; then
    log "⚠️ Some instances are unhealthy"
    exit 1
else
    log "❌ All instances are unhealthy"
    exit 2
fi