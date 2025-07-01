#!/bin/bash

# GitOps Terraform Deployment Script
# This script deploys the Goal Tracker application across dev, test, and prod environments

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
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

# Function to deploy an environment
deploy_environment() {
    local env=$1
    print_status "Deploying $env environment..."
    
    cd $env/
    
    print_status "Initializing Terraform for $env..."
    terraform init
    
    print_status "Planning Terraform deployment for $env..."
    terraform plan -out=$env.tfplan
    
    print_status "Applying Terraform configuration for $env..."
    terraform apply $env.tfplan
    
    print_success "$env environment deployed successfully!"
    
    # Get AKS credentials
    print_status "Getting AKS credentials for $env..."
    local rg_name=$(terraform output -raw resource_group_name)
    local cluster_name=$(terraform output -raw aks_cluster_name)
    
    az aks get-credentials --resource-group $rg_name --name $cluster_name --overwrite-existing
    
    print_success "AKS credentials configured for $env"
    
    cd ..
}

# Function to get ArgoCD info
get_argocd_info() {
    local env=$1
    print_status "Getting ArgoCD information for $env..."
    
    # Switch to the correct context
    kubectl config use-context aks-gitops-cluster-$env
    
    print_status "Waiting for ArgoCD server to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd
    
    print_status "Getting ArgoCD server external IP..."
    local external_ip=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    
    if [ -z "$external_ip" ]; then
        print_warning "ArgoCD external IP not yet assigned. Run the following command later:"
        echo "kubectl get svc argocd-server -n argocd"
    else
        print_success "ArgoCD URL for $env: http://$external_ip"
    fi
    
    print_status "Getting ArgoCD admin password for $env..."
    local admin_password=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
    print_success "ArgoCD admin password for $env: $admin_password"
}

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check if Azure CLI is installed and logged in
    if ! command -v az &> /dev/null; then
        print_error "Azure CLI is not installed. Please install it first."
        exit 1
    fi
    
    if ! az account show &> /dev/null; then
        print_error "Please log in to Azure CLI first: az login"
        exit 1
    fi
    
    # Check if Terraform is installed
    if ! command -v terraform &> /dev/null; then
        print_error "Terraform is not installed. Please install it first."
        exit 1
    fi
    
    # Check if kubectl is installed
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed. Please install it first."
        exit 1
    fi
    
    # Check if SSH key exists (optional)
    if [ ! -f ~/.ssh/id_rsa_azure.pub ]; then
        print_warning "SSH key not found at ~/.ssh/id_rsa_azure.pub"
        print_status "SSH key is optional when using managed identity."
        print_status "To generate SSH key for optional node access, run:"
        print_status "ssh-keygen -t rsa -b 2048 -f ~/.ssh/id_rsa_azure -N \"\""
    else
        print_success "SSH key found at ~/.ssh/id_rsa_azure.pub"
    fi
    
    # Check if managed identity is available
    print_status "Checking Azure CLI authentication method..."
    local auth_type=$(az account show --query "user.type" -o tsv 2>/dev/null || echo "unknown")
    if [ "$auth_type" = "servicePrincipal" ]; then
        print_success "Using service principal authentication"
    elif [ "$auth_type" = "user" ]; then
        print_success "Using user authentication"
    else
        print_warning "Authentication type: $auth_type"
    fi
    
    print_success "All prerequisites met!"
}

# Main deployment function
main() {
    print_status "Starting GitOps Terraform Deployment..."
    
    check_prerequisites
    
    # Get deployment choice from user
    echo "Select deployment option:"
    echo "1) Deploy all environments (dev, test, prod)"
    echo "2) Deploy specific environment"
    echo "3) Get ArgoCD information only"
    echo "4) Exit"
    
    read -p "Enter your choice (1-4): " choice
    
    case $choice in
        1)
            print_status "Deploying all environments..."
            deploy_environment "dev"
            deploy_environment "test"
            deploy_environment "prod"
            
            print_success "All environments deployed successfully!"
            
            # Get ArgoCD info for all environments
            get_argocd_info "dev"
            get_argocd_info "test"
            get_argocd_info "prod"
            ;;
        2)
            echo "Select environment to deploy:"
            echo "1) dev"
            echo "2) test"
            echo "3) prod"
            read -p "Enter your choice (1-3): " env_choice
            
            case $env_choice in
                1) deploy_environment "dev"; get_argocd_info "dev" ;;
                2) deploy_environment "test"; get_argocd_info "test" ;;
                3) deploy_environment "prod"; get_argocd_info "prod" ;;
                *) print_error "Invalid choice"; exit 1 ;;
            esac
            ;;
        3)
            echo "Select environment for ArgoCD info:"
            echo "1) dev"
            echo "2) test"
            echo "3) prod"
            read -p "Enter your choice (1-3): " info_choice
            
            case $info_choice in
                1) get_argocd_info "dev" ;;
                2) get_argocd_info "test" ;;
                3) get_argocd_info "prod" ;;
                *) print_error "Invalid choice"; exit 1 ;;
            esac
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
    
    print_success "Deployment completed!"
    print_status "Don't forget to:"
    print_status "1. Create the gitops-configs repository on GitHub"
    print_status "2. Push the gitops-configs directory contents to the repository"
    print_status "3. Access your applications via the LoadBalancer IPs"
}

# Run main function
main "$@"
