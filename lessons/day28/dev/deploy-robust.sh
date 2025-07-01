#!/bin/bash
# Robust deployment script with error handling and retries

set -e

echo "🚀 Starting Phased AKS Deployment with GitOps"
echo "=============================================="

# Function to retry terraform commands
retry_terraform() {
    local command="$1"
    local max_attempts=3
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        echo "Attempt $attempt of $max_attempts: $command"
        
        if eval "$command"; then
            echo "✅ Command succeeded on attempt $attempt"
            return 0
        else
            echo "❌ Command failed on attempt $attempt"
            if [ $attempt -eq $max_attempts ]; then
                echo "💥 All attempts failed!"
                return 1
            fi
            echo "⏳ Waiting 30 seconds before retry..."
            sleep 30
            attempt=$((attempt + 1))
        fi
    done
}

# Phase 1: Initialize Terraform
echo ""
echo "📋 Phase 1: Terraform Initialization"
echo "======================================"
terraform init -upgrade

# Phase 2: Plan and validate
echo ""
echo "📋 Phase 2: Planning Infrastructure"
echo "==================================="
terraform plan -out=tfplan

# Phase 3: Apply infrastructure only (no Kubernetes resources)
echo ""
echo "📋 Phase 3: Deploying Core Infrastructure"
echo "=========================================="
retry_terraform "terraform apply -target=azurerm_resource_group.main -target=random_string.suffix -auto-approve"

# Phase 4: Deploy AKS cluster
echo ""
echo "📋 Phase 4: Deploying AKS Cluster"
echo "=================================="
retry_terraform "terraform apply -target=azurerm_kubernetes_cluster.main -target=time_sleep.wait_for_cluster -auto-approve"

# Get AKS credentials
echo ""
echo "📋 Phase 5: Configuring kubectl"
echo "==============================="
RESOURCE_GROUP=$(terraform output -raw resource_group_name)
CLUSTER_NAME=$(terraform output -raw aks_cluster_name)

az aks get-credentials --resource-group "$RESOURCE_GROUP" --name "$CLUSTER_NAME" --overwrite-existing

# Verify cluster connectivity
echo "🔍 Verifying cluster connectivity..."
kubectl cluster-info
kubectl get nodes

# Phase 6: Deploy Kubernetes resources
echo ""
echo "📋 Phase 6: Deploying Kubernetes Resources"
echo "==========================================="
retry_terraform "terraform apply -auto-approve"

echo ""
echo "🎉 Deployment Complete!"
echo "======================="
echo ""
echo "📊 Cluster Information:"
terraform output

echo ""
echo "🔗 Next Steps:"
echo "1. Get ArgoCD admin password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
echo "2. Get ArgoCD server IP: kubectl get svc argocd-server -n argocd"
echo "3. Access ArgoCD UI with admin/<password>"
