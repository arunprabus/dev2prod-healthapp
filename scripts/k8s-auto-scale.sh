#!/bin/bash

# K8s Auto-scaling Management Script
set -e

ACTION=${1:-"status"}  # status, scale-up, scale-down, schedule
NAMESPACE=${2:-"health-app-dev"}
DEPLOYMENT=${3:-"health-api"}

log() {
    echo "$(date): $1"
}

get_current_replicas() {
    kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0"
}

get_hpa_status() {
    kubectl get hpa -n "$NAMESPACE" -o wide 2>/dev/null || echo "No HPA found"
}

scale_deployment() {
    local replicas=$1
    log "🔄 Scaling $DEPLOYMENT to $replicas replicas"
    kubectl scale deployment "$DEPLOYMENT" -n "$NAMESPACE" --replicas="$replicas"
    kubectl rollout status deployment "$DEPLOYMENT" -n "$NAMESPACE" --timeout=60s
}

schedule_scaling() {
    local hour=$(date +%H)
    
    # Business hours: 9 AM - 6 PM (scale up)
    if [[ "$hour" -ge 9 && "$hour" -lt 18 ]]; then
        current=$(get_current_replicas)
        if [[ "$current" -lt 2 ]]; then
            log "📈 Business hours - scaling up to 2 replicas"
            scale_deployment 2
        fi
    # Off hours: scale down to 1
    else
        current=$(get_current_replicas)
        if [[ "$current" -gt 1 ]]; then
            log "📉 Off hours - scaling down to 1 replica"
            scale_deployment 1
        fi
    fi
}

case "$ACTION" in
    "status")
        log "📊 Current status for $DEPLOYMENT in $NAMESPACE:"
        log "Replicas: $(get_current_replicas)"
        log "HPA Status:"
        get_hpa_status
        ;;
    "scale-up")
        current=$(get_current_replicas)
        new_replicas=$((current + 1))
        if [[ "$new_replicas" -le 5 ]]; then
            scale_deployment "$new_replicas"
        else
            log "⚠️  Maximum replicas (5) reached"
        fi
        ;;
    "scale-down")
        current=$(get_current_replicas)
        new_replicas=$((current - 1))
        if [[ "$new_replicas" -ge 1 ]]; then
            scale_deployment "$new_replicas"
        else
            log "⚠️  Minimum replicas (1) reached"
        fi
        ;;
    "schedule")
        schedule_scaling
        ;;
    *)
        log "Usage: $0 {status|scale-up|scale-down|schedule} [namespace] [deployment]"
        exit 1
        ;;
esac