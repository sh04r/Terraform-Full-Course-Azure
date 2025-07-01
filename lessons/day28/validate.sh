#!/bin/bash

# GitOps Deployment Validation Script
# This script validates the deployment across all environments

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to validate an environment
validate_environment() {
    local env=$1
    print_status "Validating $env environment..."
    
    # Switch to the correct context
    local context="aks-gitops-cluster-$env"
    if ! kubectl config use-context $context &> /dev/null; then
        print_error "Cannot switch to context $context. Is the cluster deployed?"
        return 1
    fi
    
    print_status "Checking cluster connectivity..."
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot connect to $env cluster"
        return 1
    fi
    print_success "Connected to $env cluster"
    
    # Check ArgoCD installation
    print_status "Checking ArgoCD installation..."
    if kubectl get namespace argocd &> /dev/null; then
        print_success "ArgoCD namespace exists"
        
        # Check ArgoCD pods
        local argocd_pods=$(kubectl get pods -n argocd --no-headers | wc -l)
        local ready_pods=$(kubectl get pods -n argocd --no-headers | awk '$2 ~ /^[0-9]+\/[0-9]+$/ && $3 == "Running"' | wc -l)
        print_status "ArgoCD pods: $ready_pods/$argocd_pods ready"
        
        # Check ArgoCD server service
        local argocd_service=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.spec.type}')
        print_status "ArgoCD server service type: $argocd_service"
        
        if [ "$argocd_service" = "LoadBalancer" ]; then
            local external_ip=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
            if [ -n "$external_ip" ]; then
                print_success "ArgoCD external IP: $external_ip"
            else
                print_warning "ArgoCD external IP not yet assigned"
            fi
        fi
    else
        print_error "ArgoCD namespace not found"
        return 1
    fi
    
    # Check ArgoCD Application
    print_status "Checking ArgoCD applications..."
    local app_name="goal-tracker-$env"
    if kubectl get application $app_name -n argocd &> /dev/null; then
        local app_status=$(kubectl get application $app_name -n argocd -o jsonpath='{.status.sync.status}')
        local app_health=$(kubectl get application $app_name -n argocd -o jsonpath='{.status.health.status}')
        print_status "Application $app_name - Sync: $app_status, Health: $app_health"
        
        if [ "$app_status" = "Synced" ] && [ "$app_health" = "Healthy" ]; then
            print_success "Application $app_name is healthy and synced"
        else
            print_warning "Application $app_name may have issues"
        fi
    else
        print_warning "ArgoCD application $app_name not found"
    fi
    
    # Check Goal Tracker namespace and pods
    print_status "Checking Goal Tracker application..."
    if kubectl get namespace goal-tracker &> /dev/null; then
        print_success "Goal Tracker namespace exists"
        
        # Check deployments
        local deployments=("frontend" "backend" "postgres")
        for deployment in "${deployments[@]}"; do
            if kubectl get deployment $deployment -n goal-tracker &> /dev/null; then
                local replicas=$(kubectl get deployment $deployment -n goal-tracker -o jsonpath='{.status.replicas}')
                local ready_replicas=$(kubectl get deployment $deployment -n goal-tracker -o jsonpath='{.status.readyReplicas}')
                print_status "$deployment: $ready_replicas/$replicas replicas ready"
                
                if [ "$ready_replicas" = "$replicas" ]; then
                    print_success "$deployment is fully ready"
                else
                    print_warning "$deployment is not fully ready"
                fi
            else
                print_error "$deployment deployment not found"
            fi
        done
        
        # Check services
        print_status "Checking services..."
        local services=("frontend" "backend" "postgres")
        for service in "${services[@]}"; do
            if kubectl get svc $service -n goal-tracker &> /dev/null; then
                print_success "$service service exists"
                
                if [ "$service" = "frontend" ]; then
                    local frontend_ip=$(kubectl get svc frontend -n goal-tracker -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
                    if [ -n "$frontend_ip" ]; then
                        print_success "Frontend external IP: $frontend_ip"
                        print_status "Application URL: http://$frontend_ip"
                    else
                        print_warning "Frontend external IP not yet assigned"
                    fi
                fi
            else
                print_error "$service service not found"
            fi
        done
        
        # Check PVC
        if kubectl get pvc postgres-pvc -n goal-tracker &> /dev/null; then
            local pvc_status=$(kubectl get pvc postgres-pvc -n goal-tracker -o jsonpath='{.status.phase}')
            print_status "PostgreSQL PVC status: $pvc_status"
            if [ "$pvc_status" = "Bound" ]; then
                print_success "PostgreSQL storage is bound"
            else
                print_warning "PostgreSQL storage is not bound"
            fi
        else
            print_error "PostgreSQL PVC not found"
        fi
    else
        print_error "Goal Tracker namespace not found"
    fi
    
    echo ""
}

# Function to get connection information
get_connection_info() {
    print_status "Getting connection information for all environments..."
    
    local environments=("dev" "test" "prod")
    
    for env in "${environments[@]}"; do
        print_status "=== $env Environment ==="
        
        local context="aks-gitops-cluster-$env"
        if kubectl config use-context $context &> /dev/null; then
            
            # ArgoCD info
            local argocd_ip=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "Not assigned")
            echo "ArgoCD URL: http://$argocd_ip"
            
            # Frontend info
            local frontend_ip=$(kubectl get svc frontend -n goal-tracker -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "Not assigned")
            echo "Application URL: http://$frontend_ip"
            
            # ArgoCD admin password
            local admin_password=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d || echo "Not available")
            echo "ArgoCD Admin Password: $admin_password"
            
        else
            print_error "Cannot connect to $env cluster"
        fi
        echo ""
    done
}

# Main validation function
main() {
    print_status "Starting GitOps Deployment Validation..."
    
    echo "Select validation option:"
    echo "1) Validate all environments"
    echo "2) Validate specific environment"
    echo "3) Get connection information"
    echo "4) Exit"
    
    read -p "Enter your choice (1-4): " choice
    
    case $choice in
        1)
            local environments=("dev" "test" "prod")
            for env in "${environments[@]}"; do
                validate_environment $env
            done
            print_success "Validation completed for all environments!"
            ;;
        2)
            echo "Select environment to validate:"
            echo "1) dev"
            echo "2) test"
            echo "3) prod"
            read -p "Enter your choice (1-3): " env_choice
            
            case $env_choice in
                1) validate_environment "dev" ;;
                2) validate_environment "test" ;;
                3) validate_environment "prod" ;;
                *) print_error "Invalid choice"; exit 1 ;;
            esac
            ;;
        3)
            get_connection_info
            ;;
        4)
            print_status "Exiting..."
            exit 0
            ;;
        *)
            print_error "Invalid choice"
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
