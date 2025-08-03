#!/bin/bash

# EC2 Cleanup Script
set -e

ENVIRONMENT=${1:-"dev"}
APP_NAME=${2:-"health-api"}

log() {
    echo "$(date): $1"
}

# Clean up stopped instances
log "🧹 Cleaning up stopped instances for $APP_NAME in $ENVIRONMENT"

stopped_instances=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=health-app-${APP_NAME}-${ENVIRONMENT}*" \
             "Name=instance-state-name,Values=stopped" \
    --query "Reservations[].Instances[].[InstanceId,Tags[?Key=='Name'].Value|[0]]" \
    --output text)

if [ -z "$stopped_instances" ]; then
    log "✅ No stopped instances to clean up"
else
    while IFS=$'\t' read -r instance_id instance_name; do
        if [ -n "$instance_id" ]; then
            log "🗑️ Terminating stopped instance: $instance_name ($instance_id)"
            aws ec2 terminate-instances --instance-ids $instance_id
        fi
    done <<< "$stopped_instances"
    log "✅ Cleanup completed"
fi