#!/bin/bash

# K8s Health Check Script
set -e

NAMESPACE=${1:-"health-app-dev"}
LOG_FILE="k8s-health-$(date +%Y%m%d-%H%M%S).log"

log() {
    echo "$(date): $1" | tee -a "$LOG_FILE"
}

check_namespace() {
    if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
        log "⚠️  Namespace $NAMESPACE not found, checking available namespaces..."
        
        # List available namespaces
        available=$(kubectl get namespaces -o name | sed 's/namespace\///' | grep -E '(health|default|kube-system)' | head -3)
        log "📋 Available namespaces: $(echo $available | tr '\n' ' ')"
        
        # Try to use default namespace or first available
        if kubectl get namespace default &>/dev/null; then
            NAMESPACE="default"
            log "🔄 Switching to default namespace"
        elif [[ -n "$available" ]]; then
            NAMESPACE=$(echo "$available" | head -1)
            log "🔄 Switching to namespace: $NAMESPACE"
        else
            log "❌ No suitable namespace found"
            return 1
        fi
    fi
    log "✅ Using namespace: $NAMESPACE"
}

check_deployments() {
    log "🔍 Checking deployments in $NAMESPACE"
    
    deployments=$(kubectl get deployments -n "$NAMESPACE" -o name 2>/dev/null || echo "")
    if [[ -z "$deployments" ]]; then
        log "⚠️  No deployments found in $NAMESPACE"
        return 0
    fi
    
    for deployment in $deployments; do
        name=$(echo "$deployment" | cut -d'/' -f2)
        ready=$(kubectl get deployment "$name" -n "$NAMESPACE" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
        desired=$(kubectl get deployment "$name" -n "$NAMESPACE" -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")
        
        if [[ "$ready" == "$desired" && "$ready" -gt 0 ]]; then
            log "✅ $name: $ready/$desired replicas ready"
        else
            log "❌ $name: $ready/$desired replicas ready"
        fi
    done
}

check_services() {
    log "🔍 Checking services in $NAMESPACE"
    
    services=$(kubectl get services -n "$NAMESPACE" -o name 2>/dev/null || echo "")
    for service in $services; do
        name=$(echo "$service" | cut -d'/' -f2)
        endpoints=$(kubectl get endpoints "$name" -n "$NAMESPACE" -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null || echo "")
        
        if [[ -n "$endpoints" ]]; then
            log "✅ $name: Has endpoints"
        else
            log "❌ $name: No endpoints"
        fi
    done
}

check_pods() {
    log "🔍 Checking pod health in $NAMESPACE"
    
    pods=$(kubectl get pods -n "$NAMESPACE" --no-headers 2>/dev/null || echo "")
    if [[ -z "$pods" ]]; then
        log "⚠️  No pods found in $NAMESPACE"
        return 0
    fi
    
    echo "$pods" | while read -r line; do
        name=$(echo "$line" | awk '{print $1}')
        status=$(echo "$line" | awk '{print $3}')
        ready=$(echo "$line" | awk '{print $2}')
        
        if [[ "$status" == "Running" ]]; then
            log "✅ $name: $status ($ready)"
        else
            log "❌ $name: $status ($ready)"
        fi
    done
}

check_resource_usage() {
    log "📊 Checking resource usage in $NAMESPACE"
    
    # CPU and Memory usage
    kubectl top pods -n "$NAMESPACE" 2>/dev/null | while read -r line; do
        if [[ "$line" != *"NAME"* ]]; then
            log "📈 Resource usage: $line"
        fi
    done || log "⚠️  Metrics server not available"
}

main() {
    log "🏥 Starting K8s Health Check for $NAMESPACE"
    
    check_namespace || exit 1
    check_deployments
    check_services
    check_pods
    check_resource_usage
    
    log "✅ Health check completed - see $LOG_FILE for details"
}

main "$@"