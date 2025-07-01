#!/bin/bash

# GitOps Terraform Cleanup Script
# This script destroys the Goal Tracker infrastructure across environments

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

# Function to destroy an environment
destroy_environment() {
    local env=$1
    print_warning "Destroying $env environment..."
    
    cd $env/
    
    print_status "Planning Terraform destroy for $env..."
    terraform plan -destroy -out=$env-destroy.tfplan
    
    print_warning "About to destroy $env environment. This action cannot be undone!"
    read -p "Are you sure you want to continue? (yes/no): " confirm
    
    if [ "$confirm" = "yes" ]; then
        print_status "Destroying Terraform resources for $env..."
        terraform apply $env-destroy.tfplan
        print_success "$env environment destroyed successfully!"
    else
        print_status "Skipping destruction of $env environment"
    fi
    
    cd ..
}

# Main cleanup function
main() {
    print_warning "GitOps Terraform Cleanup Script"
    print_warning "This will destroy all infrastructure resources!"
    
    echo "Select cleanup option:"
    echo "1) Destroy all environments (dev, test, prod)"
    echo "2) Destroy specific environment"
    echo "3) Exit"
    
    read -p "Enter your choice (1-3): " choice
    
    case $choice in
        1)
            print_warning "This will destroy ALL environments (dev, test, prod)!"
            read -p "Are you absolutely sure? Type 'DESTROY ALL' to confirm: " final_confirm
            
            if [ "$final_confirm" = "DESTROY ALL" ]; then
                destroy_environment "dev"
                destroy_environment "test"
                destroy_environment "prod"
                print_success "All environments destroyed!"
            else
                print_status "Cleanup cancelled"
            fi
            ;;
        2)
            echo "Select environment to destroy:"
            echo "1) dev"
            echo "2) test"
            echo "3) prod"
            read -p "Enter your choice (1-3): " env_choice
            
            case $env_choice in
                1) destroy_environment "dev" ;;
                2) destroy_environment "test" ;;
                3) destroy_environment "prod" ;;
                *) print_error "Invalid choice"; exit 1 ;;
            esac
            ;;
        3)
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
