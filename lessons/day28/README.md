# 🚀 AKS GitOps Deployment Guide

**Complete step-by-step guide to deploy AKS with GitOps using Terraform and ArgoCD**

This repository provides a production-ready setup for deploying applications to Azure Kubernetes Service (AKS) using GitOps principles with ArgoCD and Terraform.

## 📋 Table of Contents

- [Architecture Overview](#-architecture-overview)
- [Prerequisites](#-prerequisites)
- [Initial Setup](#-initial-setup)
- [Step-by-Step Deployment](#-step-by-step-deployment)
- [Verification](#-verification)
- [Troubleshooting](#-troubleshooting)
- [Clean Up](#-clean-up)

---

## 🏗️ Architecture Overview

### Components
- **Infrastructure**: Azure Kubernetes Service (AKS) clusters
- **GitOps Platform**: ArgoCD for continuous deployment
- **State Management**: Terraform with Azure Storage backend
- **Application**: Goal Tracker (Frontend + Backend + PostgreSQL)
- **Environments**: Dev, Test, Production isolation

### Directory Structure
```
├── dev/                    # Dev environment Terraform
├── test/                   # Test environment Terraform  
├── prod/                   # Prod environment Terraform
├── gitops-configs/         # GitOps application configs
│   ├── apps/goal-tracker/  # Application manifests
│   └── environments/       # Environment-specific configs
└── docker-local-deployment/ # Local development
```

---

## ✅ Prerequisites

### 1. Required Tools
```bash
# Install Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Install Terraform
wget https://releases.hashicorp.com/terraform/1.12.1/terraform_1.12.1_linux_amd64.zip
unzip terraform_1.12.1_linux_amd64.zip
sudo mv terraform /usr/local/bin/

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Install Helm
sudo snap install helm --classic

# Install kubelogin for Azure AD
curl -LO "https://github.com/Azure/kubelogin/releases/latest/download/kubelogin-linux-amd64.zip"
unzip kubelogin-linux-amd64.zip
sudo cp bin/linux_amd64/kubelogin /usr/local/bin/
```

### 2. Azure Authentication
```bash
# Login to Azure
az login

# Set your subscription (replace with your subscription ID)
az account set --subscription "your-subscription-id"

# Verify login
az account show
```

### 3. SSH Key (Optional)
```bash
# Generate SSH key for AKS nodes (optional)
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa_azure -N ""
```

---

## 🔧 Initial Setup

### 1. Clone Repository
```bash
git clone <your-repo-url>
cd Terraform-Full-Course-Azure/lessons/day28
```

### 2. Prepare Docker Images (Optional)
If you want to deploy the Goal Tracker application:
```bash
# Build and push your application images
cd docker-local-deployment
docker build -t yourusername/frontend:latest ./frontend
docker build -t yourusername/backend:latest ./backend

docker push yourusername/frontend:latest
docker push yourusername/backend:latest
```

### 3. Configure Terraform Variables
Edit the `terraform.tfvars` files in each environment:

```bash
# dev/terraform.tfvars
environment             = "dev"
location                = "eastus"
resource_group_name     = "aks-gitops-rg"
kubernetes_cluster_name = "aks-gitops-cluster"
node_count              = 2
vm_size                 = "Standard_D2s_v3"
kubernetes_version      = "1.32.5"
gitops_repo_url         = "https://github.com/yourusername/gitops-configs.git"
argocd_namespace        = "argocd"

tags = {
  Environment = "development"
  Project     = "AKS-GitOps"
  ManagedBy   = "Terraform"
}
```

---

## 🚀 Step-by-Step Deployment

### Step 1: Deploy Development Environment

```bash
cd dev/

# Remove remote backend temporarily (to avoid state locking issues)
mv backend.tf backend.tf.backup

# Initialize Terraform
terraform init

# Plan the deployment
terraform plan -out=tfplan

# Apply infrastructure
terraform apply tfplan

# Wait for cluster to be ready
terraform output
```

### Step 2: Configure kubectl Access

```bash
# Get cluster credentials
az aks get-credentials \
  --resource-group $(terraform output -raw resource_group_name) \
  --name $(terraform output -raw aks_cluster_name) \
  --admin \
  --overwrite-existing

# Convert kubeconfig for Azure AD (if using RBAC)
kubelogin convert-kubeconfig -l azurecli

# Verify connection
kubectl get nodes
```

### Step 3: Install ArgoCD

```bash
# Add ArgoCD Helm repository
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

# Install ArgoCD
helm install argocd argo/argo-cd \
  --namespace argocd \
  --create-namespace \
  --set server.service.type=LoadBalancer \
  --set server.service.loadBalancerSourceRanges="{0.0.0.0/0}" \
  --set configs.params.server\\.insecure=true \
  --set server.extraArgs="{--insecure}"

# Wait for ArgoCD to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s
```

### Step 4: Access ArgoCD

```bash
# Get LoadBalancer IP
kubectl get svc argocd-server -n argocd

# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Access ArgoCD UI
# URL: http://<EXTERNAL-IP>
# Username: admin
# Password: <password from above>
```

### Step 5: Deploy Application via GitOps

```bash
# Create ArgoCD Application
kubectl apply -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: goal-tracker-dev
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/yourusername/gitops-configs.git
    targetRevision: HEAD
    path: environments/dev
  destination:
    server: https://kubernetes.default.svc
    namespace: goal-tracker
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
EOF

# Check application status
kubectl get applications -n argocd
```

### Step 6: Deploy Additional Environments

For Test and Production environments:

```bash
# Test Environment
cd ../test/
mv backend.tf backend.tf.backup
terraform init
terraform plan -out=tfplan
terraform apply tfplan

# Production Environment  
cd ../prod/
mv backend.tf backend.tf.backup
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

---

## ✅ Verification

### Automated Validation
```bash
cd dev/
chmod +x validate-deployment.sh
./validate-deployment.sh
```

### Manual Verification
```bash
# 1. Check Terraform state
terraform state list
terraform output

# 2. Verify AKS cluster
kubectl get nodes
kubectl cluster-info

# 3. Check ArgoCD
kubectl get pods -n argocd
kubectl get svc argocd-server -n argocd

# 4. Verify applications
kubectl get applications -n argocd
kubectl get pods -n goal-tracker  # If application deployed
```

### Health Indicators
✅ **Healthy Deployment:**
- All Terraform resources in state
- AKS cluster status = "Succeeded"
- All nodes show "Ready"
- All ArgoCD pods "Running"
- LoadBalancer has external IP
- ArgoCD UI accessible
- Applications "Synced" and "Healthy"

---

## 🔧 Troubleshooting

### Common Issues and Solutions

#### 1. State Tracking Error
```bash
# Error: "Provider produced inconsistent result after apply"
# Solution: Use local state initially
mv backend.tf backend.tf.backup
terraform init -reconfigure
```

#### 2. kubectl Connection Issues
```bash
# Install kubelogin if missing
curl -LO "https://github.com/Azure/kubelogin/releases/latest/download/kubelogin-linux-amd64.zip"
unzip kubelogin-linux-amd64.zip
sudo cp bin/linux_amd64/kubelogin /usr/local/bin/

# Get admin credentials
az aks get-credentials --resource-group <rg-name> --name <cluster-name> --admin
```

#### 3. ArgoCD UI Not Accessible
```bash
# Use port forwarding as backup
kubectl port-forward svc/argocd-server -n argocd 8080:80
# Access: http://localhost:8080
```

#### 4. Application Sync Issues
```bash
# Check ArgoCD logs
kubectl logs -n argocd deployment/argocd-application-controller

# Force sync
kubectl patch application goal-tracker-dev -n argocd --type merge --patch '{"spec":{"syncPolicy":{"automated":{"prune":true,"selfHeal":true}}}}'
```

### Debug Commands
```bash
# Check all pods across namespaces
kubectl get pods --all-namespaces

# Check events
kubectl get events --sort-by=.metadata.creationTimestamp

# Check resource usage
kubectl top nodes
kubectl top pods --all-namespaces
```

---

## 🧹 Clean Up

### Remove Applications
```bash
# Delete ArgoCD applications
kubectl delete applications --all -n argocd

# Delete ArgoCD
helm uninstall argocd -n argocd
kubectl delete namespace argocd
```

### Remove Infrastructure
```bash
# Destroy each environment
cd dev/
terraform destroy -auto-approve

cd ../test/
terraform destroy -auto-approve

cd ../prod/
terraform destroy -auto-approve
```

---

## 📚 Additional Resources

### Quick Reference Commands
```bash
# Get cluster info
kubectl cluster-info

# ArgoCD password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Port forward ArgoCD
kubectl port-forward svc/argocd-server -n argocd 8080:80

# Check application status
kubectl get applications -n argocd
```

### Useful Links
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [AKS Documentation](https://docs.microsoft.com/en-us/azure/aks/)
- [Terraform AzureRM Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)

---

## 🎯 Success Criteria

Your deployment is successful when:
- ✅ AKS cluster is running and accessible
- ✅ ArgoCD UI is accessible via LoadBalancer
- ✅ Applications can be deployed via GitOps
- ✅ All validation checks pass
- ✅ No Terraform state tracking issues

**🎉 Congratulations! You now have a production-ready AKS GitOps setup!**

---

## 📊 Environment Configuration Details

### Environment Differences

| Environment | Location | Node Count | VM Size | Auto-Scaling | Replicas (Frontend/Backend) |
|-------------|----------|------------|---------|--------------|----------------------------|
| Dev         | eastus   | 2          | Standard_D2s_v3 | 1-5 nodes | 1/1 |
| Test        | eastus2  | 2          | Standard_D2s_v3 | 1-5 nodes | 2/2 |
| Prod        | westus2  | 3          | Standard_D4s_v3 | 2-10 nodes | 3/3 |

### Key Features Enabled
- ✅ **Auto-scaling**: Cluster auto-scaler enabled (min: 1, max: 5 for dev/test, 2-10 for prod)
- ✅ **Azure CNI**: Advanced networking with network policies
- ✅ **Azure AD RBAC**: Role-based access control integration
- ✅ **Container Insights**: Monitoring and logging enabled
- ✅ **Managed Identity**: System-assigned identity for secure access
- ✅ **OMS Agent**: Log Analytics integration for cluster monitoring

## 🏗️ Infrastructure Components

### Terraform Resources Deployed
1. **Resource Group**: `aks-gitops-rg-{environment}`
2. **AKS Cluster**: `aks-gitops-cluster-{environment}`
3. **Log Analytics Workspace**: For monitoring and logging
4. **Managed Identity**: System-assigned for secure Azure resource access
5. **Node Pool**: Auto-scaling enabled with appropriate VM sizes

### ArgoCD Configuration
- **Namespace**: `argocd`
- **Service Type**: LoadBalancer with external access
- **Security**: Insecure mode for demo (configure TLS for production)
- **High Availability**: Multiple replicas for production resilience

## 🔗 GitOps Repository Setup

### 1. Create GitOps Repository
```bash
# Create new repository on GitHub named 'gitops-configs'
# Or use existing repository and update the URL
```

### 2. Repository Structure
```
gitops-configs/
├── environments/
│   ├── dev/
│   │   ├── goal-tracker/
│   │   │   ├── namespace.yaml
│   │   │   ├── frontend-deployment.yaml
│   │   │   ├── backend-deployment.yaml
│   │   │   ├── postgres-deployment.yaml
│   │   │   └── services.yaml
│   │   └── kustomization.yaml
│   ├── test/
│   └── prod/
└── base/
    └── goal-tracker/
        ├── deployments/
        ├── services/
        └── configs/
```

### 3. Update Repository URL
Edit `terraform.tfvars` in each environment:
```bash
gitops_repo_url = "https://github.com/yourusername/gitops-configs.git"
```

## 📱 Application Components

### Goal Tracker Application
- **Frontend**: React application (`itsbaivab/frontend:latest`)
  - Service Type: LoadBalancer for external access
  - Replicas: Environment-specific scaling
  - Health checks: Readiness and liveness probes

- **Backend**: REST API (`itsbaivab/backend:latest`)
  - Service Type: ClusterIP (internal access only)
  - Database connection: PostgreSQL integration
  - Environment variables: Database credentials via ConfigMap/Secrets

- **Database**: PostgreSQL 15
  - Persistent Volume: Azure Disk for data persistence
  - Backup: Automated snapshots (configure separately)
  - High Availability: Consider Azure Database for PostgreSQL for production

## 📈 Monitoring and Observability

### Built-in Monitoring
```bash
# Check cluster health
kubectl get nodes
kubectl top nodes

# Monitor ArgoCD applications
kubectl get applications -n argocd

# Check application health
kubectl get pods -n goal-tracker
kubectl describe deployment frontend -n goal-tracker
```

### Azure Monitor Integration
- **Container Insights**: Real-time monitoring of containers and nodes
- **Log Analytics**: Centralized logging for troubleshooting
- **Metrics**: CPU, memory, and custom application metrics
- **Alerts**: Configure alerts for critical thresholds

### ArgoCD Monitoring
```bash
# ArgoCD CLI installation (optional)
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd

# Login to ArgoCD CLI
argocd login <ARGOCD_SERVER_IP>

# Monitor applications
argocd app list
argocd app get goal-tracker-dev
argocd app sync goal-tracker-dev
```

## 🔐 Production Security Recommendations

### 1. TLS Configuration for ArgoCD
```bash
# Generate TLS certificates
kubectl create secret tls argocd-server-tls \
  --cert=server.crt \
  --key=server.key \
  -n argocd

# Update ArgoCD server to use TLS
helm upgrade argocd argo/argo-cd \
  --namespace argocd \
  --set server.certificate.enabled=true \
  --reuse-values
```

### 2. Azure Key Vault Integration
```bash
# Install Azure Key Vault CSI driver
helm repo add secrets-store-csi-driver https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts
helm install csi-secrets-store secrets-store-csi-driver/secrets-store-csi-driver \
  --namespace kube-system
```

### 3. Network Policies
```yaml
# Example network policy for goal-tracker namespace
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: goal-tracker-network-policy
  namespace: goal-tracker
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: argocd
  egress:
  - to: []
```

## 🚨 Advanced Troubleshooting

### State Management Issues
```bash
# If you encounter state locking issues:
terraform force-unlock <LOCK_ID>

# Reset local state (use carefully):
rm -rf .terraform/
terraform init

# Import existing resources:
terraform import azurerm_resource_group.main /subscriptions/{subscription-id}/resourceGroups/{rg-name}
```

### AKS Connection Issues
```bash
# Reset kubectl configuration
az aks get-credentials --resource-group <rg-name> --name <cluster-name> --admin --overwrite-existing

# Troubleshoot kubelogin
kubelogin convert-kubeconfig -l azurecli
kubelogin remove-tokens

# Check Azure RBAC
az role assignment list --assignee $(az account show --query user.name -o tsv) --scope /subscriptions/$(az account show --query id -o tsv)
```

### ArgoCD Troubleshooting
```bash
# Check ArgoCD controller logs
kubectl logs -n argocd deployment/argocd-application-controller

# Check ArgoCD server logs
kubectl logs -n argocd deployment/argocd-server

# Reset ArgoCD admin password
kubectl -n argocd patch secret argocd-secret \
  -p '{"stringData": {
    "admin.password": "$2a$10$rRyBsGSHK6.uc8fntPwVIuLVHgsAhAX7TcdrqW/RADU0uh7CaChLa",
    "admin.passwordMtime": "'$(date +%FT%T%Z)'"
  }}'
```

## 🧹 Complete Cleanup Guide

### 1. Remove Applications and ArgoCD
```bash
# Delete all ArgoCD applications
kubectl delete applications --all -n argocd

# Wait for applications to be removed
kubectl get applications -n argocd

# Remove ArgoCD
helm uninstall argocd -n argocd
kubectl delete namespace argocd

# Remove application namespaces
kubectl delete namespace goal-tracker
```

### 2. Destroy Infrastructure
```bash
# Destroy each environment (start with dev)
cd dev/
terraform destroy -auto-approve

cd ../test/
terraform destroy -auto-approve

cd ../prod/
terraform destroy -auto-approve
```

### 3. Clean Local State (if needed)
```bash
# Remove local state files
rm -rf dev/.terraform*
rm -rf test/.terraform*
rm -rf prod/.terraform*

# Remove state backups
rm -rf */terraform.tfstate*
```

## 📚 Additional Resources and Best Practices

### Useful Commands Reference
```bash
# Quick cluster info
kubectl cluster-info dump --output-directory=/tmp/cluster-info

# Get all resources in a namespace
kubectl get all -n argocd

# Watch pod status in real-time
kubectl get pods -n goal-tracker -w

# Port forward for local access
kubectl port-forward svc/frontend -n goal-tracker 8080:80

# Scale deployments
kubectl scale deployment frontend --replicas=3 -n goal-tracker

# Check resource usage
kubectl top pods -n goal-tracker --sort-by=cpu
```

### Production Checklist
- [ ] TLS certificates configured for ArgoCD
- [ ] Azure Key Vault integration for secrets
- [ ] Network policies implemented
- [ ] Resource quotas and limits set
- [ ] Monitoring and alerting configured
- [ ] Backup strategy implemented
- [ ] RBAC properly configured
- [ ] Security scanning enabled
- [ ] Pod Security Standards enforced
- [ ] Horizontal Pod Autoscaler configured

### Learning Resources
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [ArgoCD Getting Started](https://argo-cd.readthedocs.io/en/stable/getting_started/)
- [Azure AKS Best Practices](https://docs.microsoft.com/en-us/azure/aks/best-practices)
- [GitOps Principles](https://www.gitops.tech/)
- [Terraform Azure Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)

### Support and Community
- **GitHub Issues**: Report bugs and request features
- **Community Slack**: Join Kubernetes and ArgoCD communities
- **Azure Support**: Use Azure support for AKS-specific issues
- **Stack Overflow**: Tag questions with `azure-aks`, `argocd`, `terraform`

---

## 🎯 Success Metrics

Your GitOps deployment is successful when:
- ✅ All Terraform resources deployed without state tracking errors
- ✅ AKS cluster status shows "Succeeded" in Azure portal
- ✅ All nodes are in "Ready" state
- ✅ ArgoCD UI is accessible via LoadBalancer external IP
- ✅ All ArgoCD pods are running and healthy
- ✅ Applications sync successfully from Git repository
- ✅ Application pods are running and healthy
- ✅ Services have external IPs (where configured)
- ✅ Validation script passes all checks
- ✅ No critical errors in cluster or application logs

**🚀 You now have a production-ready, scalable AKS GitOps platform!**

---

*For additional support or questions, refer to the troubleshooting section or create an issue in this repository.*
