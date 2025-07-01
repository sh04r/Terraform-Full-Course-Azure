#!/bin/bash

# 🚀 GitHub Repository Setup Script
# This script helps you push the right files to your GitHub repository

set -e

echo "🚀 Setting up GitHub repository for AKS GitOps Platform"
echo "=================================================="

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
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

# Check if we're in the right directory
if [[ ! -f "README.md" || ! -d "dev" ]]; then
    echo "❌ Error: Please run this script from the day28 directory"
    exit 1
fi

# Check if git is initialized
if [[ ! -d ".git" ]]; then
    print_status "Initializing Git repository..."
    git init
    print_success "Git repository initialized"
fi

# Check if .gitignore exists
if [[ ! -f ".gitignore" ]]; then
    print_warning ".gitignore not found - it should have been created"
    exit 1
fi

# Clean up files that shouldn't be committed
print_status "Cleaning up files that shouldn't be committed..."

# Remove Terraform state files and other sensitive files
rm -f dev/terraform.tfstate*
rm -f dev/tfplan
rm -rf dev/.terraform/
rm -f dev/.terraform.lock.hcl
rm -f dev/kubelogin-linux-amd64.zip
rm -rf dev/bin/

rm -f test/terraform.tfstate*
rm -f test/tfplan
rm -rf test/.terraform/

rm -f prod/terraform.tfstate*
rm -f prod/tfplan
rm -rf prod/.terraform/

print_success "Cleanup completed"

# Add .gitignore first
print_status "Adding .gitignore..."
git add .gitignore

# Add documentation files
print_status "Adding documentation files..."
git add README.md
git add PROJECT_SUMMARY.md
git add DEPLOYMENT_COMPLETE.md
if [[ -f "QUICKSTART.md" ]]; then
    git add QUICKSTART.md
fi

# Add utility scripts
print_status "Adding utility scripts..."
if [[ -f "deploy.sh" ]]; then git add deploy.sh; fi
if [[ -f "cleanup.sh" ]]; then git add cleanup.sh; fi
if [[ -f "validate.sh" ]]; then git add validate.sh; fi
if [[ -f "push-images.sh" ]]; then git add push-images.sh; fi

# Add Terraform configurations for dev environment
print_status "Adding dev environment Terraform files..."
git add dev/main.tf
git add dev/provider.tf
git add dev/variables.tf
git add dev/outputs.tf
git add dev/terraform.tfvars
git add dev/kubernetes-resources.tf
git add dev/deploy-robust.sh
git add dev/validate-deployment.sh
git add dev/argocd-application.yaml
git add dev/DEPLOYMENT_SUCCESS.md
git add dev/VERIFICATION_GUIDE.md

# Add test environment (if exists)
if [[ -d "test" ]]; then
    print_status "Adding test environment Terraform files..."
    git add test/main.tf
    git add test/provider.tf
    git add test/variables.tf
    git add test/outputs.tf
    git add test/terraform.tfvars
    git add test/backend.tf
fi

# Add prod environment (if exists)
if [[ -d "prod" ]]; then
    print_status "Adding prod environment Terraform files..."
    git add prod/main.tf
    git add prod/provider.tf
    git add prod/variables.tf
    git add prod/outputs.tf
    git add prod/terraform.tfvars
    git add prod/backend.tf
fi

# Add GitOps configurations
if [[ -d "gitops-configs" ]]; then
    print_status "Adding GitOps configurations..."
    git add gitops-configs/
fi

# Add Docker local development (optional)
if [[ -d "docker-local-deployment" ]]; then
    print_status "Adding Docker local development files..."
    git add docker-local-deployment/
fi

print_success "All files staged for commit"

# Show what will be committed
echo ""
echo "📋 Files staged for commit:"
echo "=========================="
git status --porcelain | grep "^A" | sed 's/^A  /✅ /'

echo ""
echo "📋 Files that will be ignored:"
echo "=============================="
echo "❌ *.tfstate (Terraform state files)"
echo "❌ *.tfstate.backup (Terraform state backups)"
echo "❌ *.tfplan (Terraform plan files)"
echo "❌ .terraform/ (Terraform working directory)"
echo "❌ bin/ (Binary files)"
echo "❌ kubelogin* (Downloaded binaries)"

echo ""
read -p "🤔 Do you want to commit these files? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    print_status "Creating initial commit..."
    git commit -m "Initial commit: AKS GitOps platform with Terraform and ArgoCD

📋 Features included:
- ✅ Complete Terraform infrastructure as code
- ✅ AKS cluster with auto-scaling and RBAC
- ✅ ArgoCD GitOps platform deployment
- ✅ Multi-environment support (dev/test/prod)
- ✅ Comprehensive documentation and guides
- ✅ Automated deployment and validation scripts
- ✅ Docker local development setup
- ✅ Kubernetes manifests and GitOps configurations

🎯 Ready for production deployment with enterprise security features."
    
    print_success "Initial commit created successfully!"
    
    echo ""
    echo "🔗 Next steps:"
    echo "=============="
    echo "1. Create a repository on GitHub"
    echo "2. Add the remote origin:"
    echo "   git remote add origin https://github.com/yourusername/your-repo-name.git"
    echo ""
    echo "3. Push to GitHub:"
    echo "   git branch -M main"
    echo "   git push -u origin main"
    echo ""
    echo "4. Update terraform.tfvars files with your new GitOps repository URL"
    
else
    print_warning "Commit cancelled. Files are still staged and ready when you're ready to commit."
fi

echo ""
print_success "GitHub repository setup complete! 🎉"
