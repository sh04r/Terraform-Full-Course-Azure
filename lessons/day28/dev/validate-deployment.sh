#!/bin/bash
# Comprehensive AKS GitOps Deployment Validation Script
# This script checks all components of your deployment

set -e

echo "🔍 AKS GitOps Deployment Validation"
echo "=================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
success() {
    echo -e "${GREEN}✅ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
}

info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

check_command() {
    if command -v $1 &> /dev/null; then
        success "$1 is installed"
        return 0
    else
        error "$1 is not installed"
        return 1
    fi
}

# 1. Prerequisites Check
echo "1️⃣  Checking Prerequisites"
echo "========================"
check_command kubectl
check_command terraform
check_command az
check_command helm
echo ""

# 2. Terraform State Validation
echo "2️⃣  Terraform State Validation"
echo "=============================="
if terraform show &> /dev/null; then
    success "Terraform state is accessible"
    
    # Check if resources exist in state
    RESOURCE_COUNT=$(terraform state list 2>/dev/null | wc -l)
    if [ $RESOURCE_COUNT -gt 0 ]; then
        success "Found $RESOURCE_COUNT resources in Terraform state"
        info "Resources:"
        terraform state list | sed 's/^/    /'
    else
        error "No resources found in Terraform state"
    fi
else
    error "Cannot access Terraform state"
fi
echo ""

# 3. AKS Cluster Validation
echo "3️⃣  AKS Cluster Validation"
echo "========================="

# Check if cluster exists
CLUSTER_NAME=$(terraform output -raw aks_cluster_name 2>/dev/null || echo "")
RESOURCE_GROUP=$(terraform output -raw resource_group_name 2>/dev/null || echo "")

if [ -n "$CLUSTER_NAME" ] && [ -n "$RESOURCE_GROUP" ]; then
    success "Cluster info: $CLUSTER_NAME in $RESOURCE_GROUP"
    
    # Check cluster status in Azure
    CLUSTER_STATUS=$(az aks show --name "$CLUSTER_NAME" --resource-group "$RESOURCE_GROUP" --query "provisioningState" -o tsv 2>/dev/null || echo "NotFound")
    
    if [ "$CLUSTER_STATUS" = "Succeeded" ]; then
        success "AKS cluster is in 'Succeeded' state"
    else
        error "AKS cluster status: $CLUSTER_STATUS"
    fi
else
    error "Cannot get cluster information from Terraform outputs"
fi
echo ""

# 4. Kubernetes Connectivity
echo "4️⃣  Kubernetes Connectivity"
echo "=========================="

if kubectl cluster-info &> /dev/null; then
    success "kubectl can connect to cluster"
    
    # Get cluster info
    info "Cluster Info:"
    kubectl cluster-info | sed 's/^/    /'
    
    # Check nodes
    NODE_COUNT=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)
    READY_NODES=$(kubectl get nodes --no-headers 2>/dev/null | grep -c " Ready " || echo 0)
    
    if [ $NODE_COUNT -gt 0 ]; then
        success "Found $NODE_COUNT nodes, $READY_NODES ready"
        info "Node Status:"
        kubectl get nodes | sed 's/^/    /'
    else
        error "No nodes found"
    fi
else
    error "Cannot connect to Kubernetes cluster"
    warning "Try: az aks get-credentials --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --admin"
fi
echo ""

# 5. ArgoCD Validation
echo "5️⃣  ArgoCD Validation"
echo "=================="

# Check if ArgoCD namespace exists
if kubectl get namespace argocd &> /dev/null; then
    success "ArgoCD namespace exists"
    
    # Check ArgoCD pods
    ARGOCD_PODS=$(kubectl get pods -n argocd --no-headers 2>/dev/null | wc -l)
    RUNNING_PODS=$(kubectl get pods -n argocd --no-headers 2>/dev/null | grep -c " Running " || echo 0)
    COMPLETED_PODS=$(kubectl get pods -n argocd --no-headers 2>/dev/null | grep -c " Completed " || echo 0)
    HEALTHY_PODS=$((RUNNING_PODS + COMPLETED_PODS))
    
    if [ $HEALTHY_PODS -eq $ARGOCD_PODS ] && [ $ARGOCD_PODS -gt 0 ]; then
        success "All $ARGOCD_PODS ArgoCD pods are healthy"
    else
        warning "$HEALTHY_PODS/$ARGOCD_PODS ArgoCD pods are healthy"
        info "Pod Status:"
        kubectl get pods -n argocd | sed 's/^/    /'
    fi
    
    # Check ArgoCD service
    ARGOCD_SVC_TYPE=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.spec.type}' 2>/dev/null || echo "NotFound")
    if [ "$ARGOCD_SVC_TYPE" = "LoadBalancer" ]; then
        EXTERNAL_IP=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "Pending")
        if [ "$EXTERNAL_IP" != "Pending" ] && [ -n "$EXTERNAL_IP" ]; then
            success "ArgoCD LoadBalancer has external IP: $EXTERNAL_IP"
            info "Access URL: http://$EXTERNAL_IP"
        else
            warning "ArgoCD LoadBalancer IP is still pending"
        fi
    else
        warning "ArgoCD service type is $ARGOCD_SVC_TYPE (expected LoadBalancer)"
    fi
    
    # Get ArgoCD admin password
    if kubectl get secret argocd-initial-admin-secret -n argocd &> /dev/null; then
        ADMIN_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d)
        if [ -n "$ADMIN_PASSWORD" ]; then
            success "ArgoCD admin password retrieved"
            info "Username: admin"
            info "Password: $ADMIN_PASSWORD"
        else
            warning "Could not retrieve ArgoCD admin password"
        fi
    else
        warning "ArgoCD initial admin secret not found"
    fi
    
else
    error "ArgoCD namespace not found"
fi
echo ""

# 6. GitOps Applications
echo "6️⃣  GitOps Applications"
echo "====================="

# Check for ArgoCD applications
if kubectl get applications -n argocd &> /dev/null; then
    APP_COUNT=$(kubectl get applications -n argocd --no-headers 2>/dev/null | wc -l)
    if [ $APP_COUNT -gt 0 ]; then
        success "Found $APP_COUNT ArgoCD application(s)"
        info "Applications:"
        kubectl get applications -n argocd | sed 's/^/    /'
        
        # Check application health
        HEALTHY_APPS=$(kubectl get applications -n argocd -o jsonpath='{.items[?(@.status.health.status=="Healthy")].metadata.name}' 2>/dev/null || echo "")
        SYNCED_APPS=$(kubectl get applications -n argocd -o jsonpath='{.items[?(@.status.sync.status=="Synced")].metadata.name}' 2>/dev/null || echo "")
        
        if [ -n "$HEALTHY_APPS" ]; then
            success "Healthy applications: $HEALTHY_APPS"
        fi
        if [ -n "$SYNCED_APPS" ]; then
            success "Synced applications: $SYNCED_APPS"
        fi
    else
        warning "No ArgoCD applications found"
        info "You can create applications using: kubectl apply -f argocd-application.yaml"
    fi
else
    warning "Cannot check ArgoCD applications (ArgoCD may not be ready)"
fi
echo ""

# 7. Network Connectivity
echo "7️⃣  Network Connectivity"
echo "======================="

# Check DNS resolution
if kubectl run test-dns --image=busybox --rm -it --restart=Never -- nslookup kubernetes.default &> /dev/null; then
    success "DNS resolution working"
else
    warning "DNS resolution test failed"
fi

# Check if we can reach external services
if kubectl run test-external --image=busybox --rm -it --restart=Never -- wget -q --spider https://google.com &> /dev/null; then
    success "External connectivity working"
else
    warning "External connectivity test failed"
fi
echo ""

# 8. Resource Usage
echo "8️⃣  Resource Usage"
echo "================="

# Node resource usage
info "Node Resource Usage:"
kubectl top nodes 2>/dev/null | sed 's/^/    /' || warning "Metrics server not available"

# Pod resource usage
info "Pod Resource Usage (top 10):"
kubectl top pods --all-namespaces --sort-by=memory 2>/dev/null | head -11 | sed 's/^/    /' || warning "Metrics server not available"
echo ""

# 9. Health Summary
echo "9️⃣  Health Summary"
echo "================"

# Overall status
TERRAFORM_OK=$(terraform show &> /dev/null && echo "true" || echo "false")
KUBECTL_OK=$(kubectl cluster-info &> /dev/null && echo "true" || echo "false")
ARGOCD_OK=$(kubectl get pods -n argocd &> /dev/null && echo "true" || echo "false")

if [ "$TERRAFORM_OK" = "true" ] && [ "$KUBECTL_OK" = "true" ] && [ "$ARGOCD_OK" = "true" ]; then
    success "🎉 Deployment is HEALTHY! All core components are working."
elif [ "$TERRAFORM_OK" = "true" ] && [ "$KUBECTL_OK" = "true" ]; then
    warning "⚠️  Infrastructure is working, but ArgoCD needs attention."
elif [ "$TERRAFORM_OK" = "true" ]; then
    warning "⚠️  Terraform state is good, but Kubernetes connectivity issues."
else
    error "❌ Multiple issues detected. Check Terraform state first."
fi

echo ""
echo "🔧 Quick Fix Commands:"
echo "====================="
echo "# Get cluster credentials:"
echo "az aks get-credentials --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --admin"
echo ""
echo "# Check ArgoCD status:"
echo "kubectl get pods -n argocd"
echo ""
echo "# Access ArgoCD UI:"
echo "kubectl get svc argocd-server -n argocd"
echo ""
echo "# Get ArgoCD password:"
echo "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
echo ""
echo "# Port forward to ArgoCD (if LoadBalancer not working):"
echo "kubectl port-forward svc/argocd-server -n argocd 8080:80"
echo ""

echo "✅ Validation Complete!"
