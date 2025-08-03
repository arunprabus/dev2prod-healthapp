#!/bin/bash

# 🎓 Kubernetes Learning Commands Script
set -e

COMMAND=${1:-"help"}
NAMESPACE="learning-k8s"

log() {
    echo "$(date): $1"
}

show_help() {
    echo "🎓 Kubernetes Learning Commands"
    echo "================================"
    echo ""
    echo "Basic Commands:"
    echo "  ./k8s-learning-commands.sh cluster-info    # Show cluster information"
    echo "  ./k8s-learning-commands.sh nodes           # List all nodes"
    echo "  ./k8s-learning-commands.sh namespaces      # List all namespaces"
    echo ""
    echo "Deployment Commands:"
    echo "  ./k8s-learning-commands.sh deploy          # Deploy learning app"
    echo "  ./k8s-learning-commands.sh status          # Check deployment status"
    echo "  ./k8s-learning-commands.sh pods            # List pods"
    echo "  ./k8s-learning-commands.sh services        # List services"
    echo ""
    echo "Learning Commands:"
    echo "  ./k8s-learning-commands.sh describe-pod    # Describe a pod"
    echo "  ./k8s-learning-commands.sh logs            # View pod logs"
    echo "  ./k8s-learning-commands.sh exec            # Execute into pod"
    echo "  ./k8s-learning-commands.sh port-forward    # Port forward to pod"
    echo ""
    echo "Scaling Commands:"
    echo "  ./k8s-learning-commands.sh scale-up        # Scale to 3 replicas"
    echo "  ./k8s-learning-commands.sh scale-down      # Scale to 1 replica"
    echo "  ./k8s-learning-commands.sh hpa-status      # Check auto-scaler"
    echo ""
    echo "Cleanup Commands:"
    echo "  ./k8s-learning-commands.sh cleanup         # Remove learning resources"
}

cluster_info() {
    log "🔍 Cluster Information"
    kubectl cluster-info
    echo ""
    kubectl version --short
}

list_nodes() {
    log "📋 Cluster Nodes"
    kubectl get nodes -o wide
}

list_namespaces() {
    log "📋 All Namespaces"
    kubectl get namespaces
}

deploy_learning_app() {
    log "🚀 Deploying learning application"
    kubectl apply -f k8s/learning-deployment.yaml
    
    log "⏳ Waiting for deployment to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/learning-app -n $NAMESPACE
    
    log "✅ Deployment completed!"
    kubectl get all -n $NAMESPACE
}

check_status() {
    log "📊 Deployment Status"
    echo "Deployments:"
    kubectl get deployments -n $NAMESPACE
    echo ""
    echo "Pods:"
    kubectl get pods -n $NAMESPACE -o wide
    echo ""
    echo "Services:"
    kubectl get services -n $NAMESPACE
    echo ""
    echo "HPA:"
    kubectl get hpa -n $NAMESPACE
}

list_pods() {
    log "📋 Pods in $NAMESPACE"
    kubectl get pods -n $NAMESPACE -o wide
    echo ""
    echo "Pod Details:"
    kubectl get pods -n $NAMESPACE -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,NODE:.spec.nodeName,IP:.status.podIP
}

list_services() {
    log "🌐 Services in $NAMESPACE"
    kubectl get services -n $NAMESPACE -o wide
}

describe_pod() {
    local pod_name=$(kubectl get pods -n $NAMESPACE -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [ -n "$pod_name" ]; then
        log "🔍 Describing pod: $pod_name"
        kubectl describe pod $pod_name -n $NAMESPACE
    else
        log "❌ No pods found in namespace $NAMESPACE"
    fi
}

view_logs() {
    local pod_name=$(kubectl get pods -n $NAMESPACE -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [ -n "$pod_name" ]; then
        log "📜 Logs from pod: $pod_name"
        kubectl logs $pod_name -n $NAMESPACE --tail=50
        echo ""
        log "💡 To follow logs in real-time, use: kubectl logs -f $pod_name -n $NAMESPACE"
    else
        log "❌ No pods found in namespace $NAMESPACE"
    fi
}

exec_into_pod() {
    local pod_name=$(kubectl get pods -n $NAMESPACE -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [ -n "$pod_name" ]; then
        log "🔧 Executing into pod: $pod_name"
        log "💡 You'll be inside the container. Type 'exit' to return."
        kubectl exec -it $pod_name -n $NAMESPACE -- /bin/bash
    else
        log "❌ No pods found in namespace $NAMESPACE"
    fi
}

port_forward() {
    local pod_name=$(kubectl get pods -n $NAMESPACE -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [ -n "$pod_name" ]; then
        log "🌐 Port forwarding from pod: $pod_name"
        log "💡 Access the app at: http://localhost:8080"
        log "💡 Press Ctrl+C to stop port forwarding"
        kubectl port-forward $pod_name 8080:80 -n $NAMESPACE
    else
        log "❌ No pods found in namespace $NAMESPACE"
    fi
}

scale_up() {
    log "📈 Scaling up to 3 replicas"
    kubectl scale deployment learning-app --replicas=3 -n $NAMESPACE
    
    log "⏳ Waiting for scale up..."
    kubectl wait --for=condition=available --timeout=60s deployment/learning-app -n $NAMESPACE
    
    kubectl get pods -n $NAMESPACE
}

scale_down() {
    log "📉 Scaling down to 1 replica"
    kubectl scale deployment learning-app --replicas=1 -n $NAMESPACE
    
    log "⏳ Waiting for scale down..."
    sleep 10
    
    kubectl get pods -n $NAMESPACE
}

hpa_status() {
    log "📊 Horizontal Pod Autoscaler Status"
    kubectl get hpa -n $NAMESPACE
    echo ""
    kubectl describe hpa learning-hpa -n $NAMESPACE
}

cleanup() {
    log "🧹 Cleaning up learning resources"
    kubectl delete namespace $NAMESPACE --ignore-not-found=true
    log "✅ Cleanup completed"
}

case "$COMMAND" in
    "help"|"--help"|"-h")
        show_help
        ;;
    "cluster-info")
        cluster_info
        ;;
    "nodes")
        list_nodes
        ;;
    "namespaces")
        list_namespaces
        ;;
    "deploy")
        deploy_learning_app
        ;;
    "status")
        check_status
        ;;
    "pods")
        list_pods
        ;;
    "services")
        list_services
        ;;
    "describe-pod")
        describe_pod
        ;;
    "logs")
        view_logs
        ;;
    "exec")
        exec_into_pod
        ;;
    "port-forward")
        port_forward
        ;;
    "scale-up")
        scale_up
        ;;
    "scale-down")
        scale_down
        ;;
    "hpa-status")
        hpa_status
        ;;
    "cleanup")
        cleanup
        ;;
    *)
        log "❌ Unknown command: $COMMAND"
        show_help
        exit 1
        ;;
esac