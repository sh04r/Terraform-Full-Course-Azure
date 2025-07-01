#!/bin/bash

# 🚀 Deploy ArgoCD Applications for Simplified GitOps Structure
echo "🚀 Creating ArgoCD Applications for Goal Tracker"
echo "=============================================="

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
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

# Check if ArgoCD is running
print_status "Checking ArgoCD status..."
if ! kubectl get pods -n argocd | grep -q "Running"; then
    print_warning "ArgoCD pods may not be running. Please check ArgoCD installation."
fi

# Delete any existing applications
print_status "Cleaning up existing applications..."
kubectl delete application goal-tracker-dev -n argocd --ignore-not-found=true
kubectl delete application goal-tracker-test -n argocd --ignore-not-found=true
kubectl delete application goal-tracker-prod -n argocd --ignore-not-found=true

# Wait a moment for cleanup
sleep 5

# Create Dev Application
print_status "Creating Development Application..."
cat << EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: goal-tracker-dev
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://github.com/itsBaivab/gitops-configs.git
    targetRevision: HEAD
    path: dev
  destination:
    server: https://kubernetes.default.svc
    namespace: goal-tracker
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
    - ServerSideApply=true
EOF

if [ $? -eq 0 ]; then
    print_success "Development application created successfully"
else
    print_warning "Failed to create development application"
fi

# Create Test Application
print_status "Creating Test Application..."
cat << EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: goal-tracker-test
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://github.com/itsBaivab/gitops-configs.git
    targetRevision: HEAD
    path: test
  destination:
    server: https://kubernetes.default.svc
    namespace: goal-tracker-test
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
    - ServerSideApply=true
EOF

if [ $? -eq 0 ]; then
    print_success "Test application created successfully"
else
    print_warning "Failed to create test application"
fi

# Create Production Application (manual sync for safety)
print_status "Creating Production Application..."
cat << EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: goal-tracker-prod
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://github.com/itsBaivab/gitops-configs.git
    targetRevision: HEAD
    path: prod
  destination:
    server: https://kubernetes.default.svc
    namespace: goal-tracker-prod
  syncPolicy:
    syncOptions:
    - CreateNamespace=true
    - ServerSideApply=true
    # Note: Production is manual sync for safety
EOF

if [ $? -eq 0 ]; then
    print_success "Production application created successfully (manual sync)"
else
    print_warning "Failed to create production application"
fi

# Show application status
echo ""
print_status "Checking ArgoCD Applications..."
kubectl get applications -n argocd

echo ""
print_status "Application Health Status:"
kubectl get applications -n argocd -o custom-columns=NAME:.metadata.name,HEALTH:.status.health.status,SYNC:.status.sync.status

echo ""
print_success "🎉 ArgoCD Applications created successfully!"
echo ""
echo "📋 Next Steps:"
echo "1. Access ArgoCD UI: http://4.156.110.77"
echo "2. Monitor application sync status"
echo "3. Check application health in the UI"
echo "4. Access Goal Tracker frontend via LoadBalancer IP"
echo ""
echo "🔍 Quick Commands:"
echo "# Check pods in dev environment"
echo "kubectl get pods -n goal-tracker"
echo ""
echo "# Get frontend service IP"
echo "kubectl get service frontend -n goal-tracker"
echo ""
echo "# Watch applications sync"
echo "kubectl get applications -n argocd -w"
