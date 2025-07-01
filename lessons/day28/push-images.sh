#!/bin/bash

# Docker Hub Image Push Script
# This script helps build and push images to Docker Hub for the GitOps deployment

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

# Function to get ACR login server for an environment
get_acr_info() {
    local env=$1
    print_status "Getting ACR information for $env environment..."
    
    cd $env/
    if [ ! -f terraform.tfstate ]; then
        print_error "Terraform state not found for $env. Please deploy the environment first."
        cd ..
        return 1
    fi
    
    local acr_name=$(terraform output -raw acr_name 2>/dev/null || echo "")
    local acr_login_server=$(terraform output -raw acr_login_server 2>/dev/null || echo "")
    
    if [ -z "$acr_name" ] || [ -z "$acr_login_server" ]; then
        print_error "Could not get ACR information for $env environment"
        cd ..
        return 1
    fi
    
    cd ..
    echo "$acr_name:$acr_login_server"
}

# Function to build and push images
build_and_push() {
    local env=$1
    local tag=$2
    
    print_status "Building and pushing images for $env environment with tag: $tag"
    
    # Get ACR information
    local acr_info=$(get_acr_info $env)
    if [ $? -ne 0 ]; then
        return 1
    fi
    
    local acr_name=$(echo $acr_info | cut -d: -f1)
    local acr_login_server=$(echo $acr_info | cut -d: -f2)
    
    print_status "ACR: $acr_login_server"
    
    # Login to ACR
    print_status "Logging in to ACR..."
    az acr login --name $acr_name
    
    # Build and push frontend
    if [ -d "../frontend" ]; then
        print_status "Building frontend image..."
        docker build -t $acr_login_server/frontend:$tag ../frontend
        
        print_status "Pushing frontend image to ACR..."
        docker push $acr_login_server/frontend:$tag
        print_success "Frontend image pushed successfully"
    else
        print_warning "Frontend directory not found, skipping frontend build"
    fi
    
    # Build and push backend
    if [ -d "../backend" ]; then
        print_status "Building backend image..."
        docker build -t $acr_login_server/backend:$tag ../backend
        
        print_status "Pushing backend image to ACR..."
        docker push $acr_login_server/backend:$tag
        print_success "Backend image pushed successfully"
    else
        print_warning "Backend directory not found, skipping backend build"
    fi
    
    print_success "All images pushed to $acr_login_server with tag: $tag"
    
    # Update GitOps configurations
    print_status "Updating GitOps configurations..."
    update_gitops_config $env $acr_login_server $tag
}

# Function to update GitOps configurations with new image references
update_gitops_config() {
    local env=$1
    local acr_login_server=$2
    local tag=$3
    
    local kustomization_file="gitops-configs/apps/goal-tracker/overlays/$env/kustomization.yaml"
    
    if [ -f "$kustomization_file" ]; then
        print_status "Updating $kustomization_file with ACR images..."
        
        # Create a backup
        cp "$kustomization_file" "$kustomization_file.backup"
        
        # Update the image references
        sed -i "s|name: itsbaivab/backend|name: $acr_login_server/backend|g" "$kustomization_file"
        sed -i "s|name: itsbaivab/frontend|name: $acr_login_server/frontend|g" "$kustomization_file"
        sed -i "s|newTag: latest|newTag: $tag|g" "$kustomization_file"
        
        print_success "Updated GitOps configuration for $env"
        print_warning "Don't forget to commit and push the GitOps repository changes!"
    else
        print_warning "GitOps configuration file not found: $kustomization_file"
    fi
}

# Function to push to DockerHub (fallback option)
push_to_dockerhub() {
    local tag=$1
    
    print_status "Building and pushing images to DockerHub with tag: $tag"
    
    # Build and push frontend
    if [ -d "../frontend" ]; then
        print_status "Building frontend image..."
        docker build -t itsbaivab/frontend:$tag ../frontend
        
        print_status "Pushing frontend image to DockerHub..."
        docker push itsbaivab/frontend:$tag
        print_success "Frontend image pushed to DockerHub"
    fi
    
    # Build and push backend
    if [ -d "../backend" ]; then
        print_status "Building backend image..."
        docker build -t itsbaivab/backend:$tag ../backend
        
        print_status "Pushing backend image to DockerHub..."
        docker push itsbaivab/backend:$tag
        print_success "Backend image pushed to DockerHub"
    fi
    
    print_success "All images pushed to DockerHub with tag: $tag"
}

# Main function
main() {
    print_status "Docker Image Build and Push Script"
    
    # Check prerequisites
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed. Please install it first."
        exit 1
    fi
    
    if ! command -v az &> /dev/null; then
        print_error "Azure CLI is not installed. Please install it first."
        exit 1
    fi
    
    echo "Select deployment target:"
    echo "1) Push to ACR for specific environment"
    echo "2) Push to ACR for all environments"
    echo "3) Push to DockerHub (legacy)"
    echo "4) Exit"
    
    read -p "Enter your choice (1-4): " choice
    
    # Get image tag
    read -p "Enter image tag (default: latest): " tag
    tag=${tag:-latest}
    
    case $choice in
        1)
            echo "Select environment:"
            echo "1) dev"
            echo "2) test"
            echo "3) prod"
            read -p "Enter your choice (1-3): " env_choice
            
            case $env_choice in
                1) build_and_push "dev" "$tag" ;;
                2) build_and_push "test" "$tag" ;;
                3) build_and_push "prod" "$tag" ;;
                *) print_error "Invalid choice"; exit 1 ;;
            esac
            ;;
        2)
            print_status "Building and pushing to all environment ACRs..."
            build_and_push "dev" "$tag"
            build_and_push "test" "$tag"
            build_and_push "prod" "$tag"
            ;;
        3)
            push_to_dockerhub "$tag"
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
    
    print_success "Image deployment completed!"
}

# Run main function
main "$@"
