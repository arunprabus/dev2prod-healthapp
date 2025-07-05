#!/bin/bash

# Kubeconfig S3 Management Script
# Usage: ./manage-kubeconfig-s3.sh [list|download|upload|delete] [environment] [local-file]

set -e

# Configuration
S3_BUCKET="${TF_STATE_BUCKET:-health-app-terraform-state}"
S3_PREFIX="kubeconfig"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

# Show usage
show_usage() {
    echo "Kubeconfig S3 Management Script"
    echo ""
    echo "Usage: $0 [COMMAND] [ENVIRONMENT] [LOCAL_FILE]"
    echo ""
    echo "Commands:"
    echo "  list                    - List all kubeconfig files in S3"
    echo "  download [env]          - Download kubeconfig for environment"
    echo "  upload [env] [file]     - Upload kubeconfig for environment"
    echo "  delete [env]            - Delete kubeconfig for environment"
    echo "  sync [env] [cluster-ip] - Generate and upload kubeconfig from cluster"
    echo ""
    echo "Environments:"
    echo "  dev, test, prod, monitoring, lower, higher"
    echo ""
    echo "Examples:"
    echo "  $0 list"
    echo "  $0 download dev"
    echo "  $0 upload dev ~/.kube/config"
    echo "  $0 sync dev 1.2.3.4"
    echo ""
}

# List all kubeconfig files in S3
list_kubeconfigs() {
    log_info "Listing kubeconfig files in S3..."
    
    if aws s3 ls s3://$S3_BUCKET/$S3_PREFIX/ 2>/dev/null; then
        log_success "Found kubeconfig files"
    else
        log_warning "No kubeconfig files found or S3 bucket not accessible"
    fi
}

# Download kubeconfig for environment
download_kubeconfig() {
    local env=$1
    local output_file=${2:-~/.kube/config-$env}
    
    if [[ -z "$env" ]]; then
        log_error "Environment required"
        show_usage
        exit 1
    fi
    
    # Determine S3 paths to try
    local s3_paths=()
    case $env in
        "dev")
            s3_paths=("dev-network.yaml" "lower-network.yaml")
            ;;
        "test")
            s3_paths=("test-network.yaml" "lower-network.yaml")
            ;;
        "prod")
            s3_paths=("prod-network.yaml" "higher-network.yaml")
            ;;
        "monitoring")
            s3_paths=("monitoring-network.yaml")
            ;;
        "lower"|"higher")
            s3_paths=("$env-network.yaml")
            ;;
        *)
            log_error "Unknown environment: $env"
            exit 1
            ;;
    esac
    
    log_info "Downloading kubeconfig for $env environment..."
    
    # Try each path
    for s3_path in "${s3_paths[@]}"; do
        local full_s3_path="s3://$S3_BUCKET/$S3_PREFIX/$s3_path"
        log_info "Trying: $full_s3_path"
        
        if aws s3 cp "$full_s3_path" "$output_file" 2>/dev/null; then
            log_success "Downloaded kubeconfig to: $output_file"
            log_info "To use: export KUBECONFIG=$output_file"
            return 0
        fi
    done
    
    log_error "Kubeconfig not found for environment: $env"
    exit 1
}

# Upload kubeconfig for environment
upload_kubeconfig() {
    local env=$1
    local local_file=$2
    
    if [[ -z "$env" || -z "$local_file" ]]; then
        log_error "Environment and local file required"
        show_usage
        exit 1
    fi
    
    if [[ ! -f "$local_file" ]]; then
        log_error "Local file not found: $local_file"
        exit 1
    fi
    
    # Determine S3 path
    local s3_path
    case $env in
        "dev"|"test"|"prod"|"monitoring")
            s3_path="$env-network.yaml"
            ;;
        "lower"|"higher")
            s3_path="$env-network.yaml"
            ;;
        *)
            log_error "Unknown environment: $env"
            exit 1
            ;;
    esac
    
    local full_s3_path="s3://$S3_BUCKET/$S3_PREFIX/$s3_path"
    
    log_info "Uploading kubeconfig for $env environment..."
    log_info "Local file: $local_file"
    log_info "S3 destination: $full_s3_path"
    
    if aws s3 cp "$local_file" "$full_s3_path"; then
        log_success "Kubeconfig uploaded successfully"
        
        # Create additional copies for network environments
        case $env in
            "lower")
                aws s3 cp "$local_file" "s3://$S3_BUCKET/$S3_PREFIX/dev-network.yaml"
                aws s3 cp "$local_file" "s3://$S3_BUCKET/$S3_PREFIX/test-network.yaml"
                log_success "Created dev and test copies"
                ;;
            "higher")
                aws s3 cp "$local_file" "s3://$S3_BUCKET/$S3_PREFIX/prod-network.yaml"
                log_success "Created prod copy"
                ;;
        esac
    else
        log_error "Failed to upload kubeconfig"
        exit 1
    fi
}

# Delete kubeconfig for environment
delete_kubeconfig() {
    local env=$1
    
    if [[ -z "$env" ]]; then
        log_error "Environment required"
        show_usage
        exit 1
    fi
    
    log_warning "Deleting kubeconfig for $env environment..."
    
    # Determine files to delete
    local files_to_delete=()
    case $env in
        "dev")
            files_to_delete=("dev-network.yaml")
            ;;
        "test")
            files_to_delete=("test-network.yaml")
            ;;
        "prod")
            files_to_delete=("prod-network.yaml")
            ;;
        "monitoring")
            files_to_delete=("monitoring-network.yaml")
            ;;
        "lower")
            files_to_delete=("lower-network.yaml" "dev-network.yaml" "test-network.yaml")
            ;;
        "higher")
            files_to_delete=("higher-network.yaml" "prod-network.yaml")
            ;;
        *)
            log_error "Unknown environment: $env"
            exit 1
            ;;
    esac
    
    # Delete files
    for file in "${files_to_delete[@]}"; do
        local full_s3_path="s3://$S3_BUCKET/$S3_PREFIX/$file"
        if aws s3 rm "$full_s3_path" 2>/dev/null; then
            log_success "Deleted: $file"
        else
            log_warning "Not found: $file"
        fi
    done
}

# Sync kubeconfig from cluster
sync_kubeconfig() {
    local env=$1
    local cluster_ip=$2
    
    if [[ -z "$env" || -z "$cluster_ip" ]]; then
        log_error "Environment and cluster IP required"
        show_usage
        exit 1
    fi
    
    log_info "Syncing kubeconfig from cluster: $cluster_ip"
    
    # Create temporary file
    local temp_file="/tmp/kubeconfig-$env-$(date +%s).yaml"
    
    # Get kubeconfig from cluster
    if ssh -i ~/.ssh/aws-key -o StrictHostKeyChecking=no -o ConnectTimeout=30 ubuntu@$cluster_ip 'sudo cat /etc/rancher/k3s/k3s.yaml' > /tmp/k3s-raw; then
        # Process kubeconfig
        sed "s|127.0.0.1:6443|$cluster_ip:6443|g" /tmp/k3s-raw | \
        sed "s|name: default|name: health-app-$env|g" | \
        sed "s|cluster: default|cluster: health-app-$env|g" | \
        sed "s|context: default|context: health-app-$env|g" | \
        sed "s|current-context: default|current-context: health-app-$env|g" > "$temp_file"
        
        log_success "Generated kubeconfig from cluster"
        
        # Upload to S3
        upload_kubeconfig "$env" "$temp_file"
        
        # Cleanup
        rm -f /tmp/k3s-raw "$temp_file"
    else
        log_error "Failed to get kubeconfig from cluster"
        exit 1
    fi
}

# Main script
main() {
    local command=$1
    
    case $command in
        "list")
            list_kubeconfigs
            ;;
        "download")
            download_kubeconfig "$2" "$3"
            ;;
        "upload")
            upload_kubeconfig "$2" "$3"
            ;;
        "delete")
            delete_kubeconfig "$2"
            ;;
        "sync")
            sync_kubeconfig "$2" "$3"
            ;;
        "help"|"-h"|"--help"|"")
            show_usage
            ;;
        *)
            log_error "Unknown command: $command"
            show_usage
            exit 1
            ;;
    esac
}

# Run main function
main "$@"