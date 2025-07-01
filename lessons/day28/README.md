# 🚀 AKS GitOps Deployment Guide

**Complete step-by-step guide to deploy AKS with GitOps using Terraform and ArgoCD**

This repository provides a production-ready setup for deploying applications to Azure Kubernetes Service (AKS) using GitOps principles with ArgoCD and Terraform.

## 📋 Table of Contents

- [Architecture Overview](#-architecture-overview)
- [Prerequisites](#-prerequisites)
- [Quick Start](#-quick-start)
- [Accessing ArgoCD WebUI](#-accessing-argocd-webui)
- [Deploying Applications](#-deploying-applications)
- [Verification](#-verification)
- [Troubleshooting](#-troubleshooting)
- [Clean Up](#-clean-up)

---

## 🏗️ Architecture Overview

### Components

- **Infrastructure**: Azure Kubernetes Service (AKS) with auto-scaling
- **GitOps Platform**: ArgoCD for continuous deployment
- **State Management**: Terraform with remote state (optional)
- **Authentication**: Azure AD integration with local admin accounts
- **Networking**: Azure CNI with network policies

### Environment Structure

```text
.
├── dev                     dev env
│   ├── argocd-app-manifest.yaml
│   ├── backend.tf
│   ├── backend.tf.example
│   ├── deploy-argocd-app.sh
│   ├── kubernetes-resources.tf
│   ├── main.tf
│   ├── outputs.tf
│   ├── provider.tf
│   ├── terraform.tfvars
│   ├── validate-deployment.sh
│   └── variables.tf
├── prod           #prod env
│   ├── argocd-app-manifest.yaml
│   ├── backend.tf
│   ├── backend.tf.example
│   ├── deploy-argocd-app.sh
│   ├── kubernetes-resources.tf
│   ├── main.tf
│   ├── outputs.tf
│   ├── provider.tf
│   ├── terraform.tfvars
│   └── variables.tf
├── README.md
└── test            #testing env
    ├── argocd-app-manifest.yaml
    ├── backend.tf
    ├── backend.tf.example
    ├── deploy-argocd-app.sh
    ├── kubernetes-resources.tf
    ├── main.tf
    ├── outputs.tf
    ├── provider.tf
    ├── terraform.tfvars
    └── variables.tf

```

---

## ✅ Prerequisites

### 1. Essential Tools (Required)

```bash
# Install Azure CLI (Required for authentication and service principal)
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Install Terraform (latest) (Required to deploy infrastructure)
sudo apt-get update && sudo apt-get install -y gnupg software-properties-common
wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform
```

### 2. Optional Tools (for manual management)

```bash
# Install kubectl (for manual cluster operations - Terraform handles K8s deployment)
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Install Helm (for manual chart operations - Terraform uses Helm provider)
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

> **Note:** Terraform automatically handles ArgoCD installation, Kubernetes resources, and application deployment via providers. You only need kubectl/helm for manual troubleshooting and verification.

### 3. Azure Authentication & Service Principal

#### Step 1: Login to Azure
```bash
# Login to Azure
az login

# Set your subscription
az account set --subscription "your-subscription-id"

# Verify authentication
az account show
```

#### Step 2: Create Service Principal for Terraform
```bash
# Get your subscription ID
SUBSCRIPTION_ID=$(az account show --query id --output tsv)
echo "Subscription ID: $SUBSCRIPTION_ID"

# Create service principal with Contributor role
az ad sp create-for-rbac \
  --name "terraform-aks-gitops" \
  --role "Contributor" \
  --scopes "/subscriptions/$SUBSCRIPTION_ID" \
  --sdk-auth

# Save the output - you'll need these values for Terraform authentication:
# {
#   "clientId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
#   "clientSecret": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
#   "subscriptionId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
#   "tenantId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
# }
```

#### Step 3: Configure Terraform Authentication

**Option A: Environment Variables (Recommended)**
```bash
# Export service principal credentials
export ARM_CLIENT_ID="your-client-id"
export ARM_CLIENT_SECRET="your-client-secret"
export ARM_SUBSCRIPTION_ID="your-subscription-id"
export ARM_TENANT_ID="your-tenant-id"

# Verify Terraform can authenticate
terraform version
```

**Option B: Azure CLI Authentication (Alternative)**
```bash
# If you prefer to use Azure CLI authentication instead of service principal
az login
az account set --subscription "your-subscription-id"
```

### 4. SSH Key (Optional)

```bash
# Generate SSH key for node access (optional)
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa_azure -N ""
```

---

## ⚡ Quick Start

### Step 1: Set Up Authentication

```bash
# Option A: Using Service Principal (Recommended for automation)
export ARM_CLIENT_ID="your-client-id"
export ARM_CLIENT_SECRET="your-client-secret"
export ARM_SUBSCRIPTION_ID="your-subscription-id"
export ARM_TENANT_ID="your-tenant-id"

# Option B: Using Azure CLI (Alternative)
az login
az account set --subscription "your-subscription-id"
```

### Step 2: Configure Remote State Backend (Optional but Recommended)

```bash
# Navigate to dev environment
cd dev/

# Option A: Use local state (for testing)
# Skip this step - Terraform will use local state by default

# Option B: Configure Azure Storage Backend (for production)
# Copy the example backend configuration
cp backend.tf.example backend.tf

# Edit backend.tf with your Azure Storage Account details
# You'll need to create these resources first or use existing ones
```

**To set up Azure Storage Backend:**

```bash
# Create resource group for Terraform state
az group create --name "rg-terraform-state" --location "East US"

# Create storage account (name must be globally unique)
STORAGE_ACCOUNT_NAME="tfstate$(date +%s)"
az storage account create \
  --resource-group "rg-terraform-state" \
  --name "$STORAGE_ACCOUNT_NAME" \
  --sku "Standard_LRS" \
  --encryption-services blob

# Create storage container
az storage container create \
  --name "tfstate" \
  --account-name "$STORAGE_ACCOUNT_NAME"

# Update backend.tf with your values
echo "Update backend.tf with these values:"
echo "resource_group_name  = \"rg-terraform-state\""
echo "storage_account_name = \"$STORAGE_ACCOUNT_NAME\""
echo "container_name       = \"tfstate\""
echo "key                  = \"dev/terraform.tfstate\""
```

### Step 3: Deploy Development Environment

```bash
# Initialize Terraform (this will configure the backend if using remote state)
terraform init

# Review what will be created
terraform plan

# Deploy infrastructure (takes 5-10 minutes)
terraform apply -auto-approve
```

> **What Terraform Deploys Automatically:**
> - ✅ AKS cluster with auto-scaling
> - ✅ ArgoCD installation via Helm
> - ✅ Azure AD integration and RBAC
> - ✅ Network policies and security groups
> - ✅ Sample guestbook application via GitOps

### Step 4: Configure kubectl Access

```bash
# Get cluster credentials using admin access
az aks get-credentials \
  --resource-group $(terraform output -raw resource_group_name) \
  --name $(terraform output -raw aks_cluster_name) \
  --admin \
  --overwrite-existing

# Verify cluster connectivity
kubectl get nodes
kubectl get namespaces
```

### Step 5: Verify ArgoCD Installation

```bash
# Check if ArgoCD is running
kubectl get pods -n argocd

# Check ArgoCD service
kubectl get svc -n argocd
```

---

## 🏢 Multi-Environment Setup

This repository provides three fully configured environments with progressive resource allocation:

### Environment Specifications

| Environment | Location | VM Size | Node Count | Auto-Scaling | OS Disk | Use Case |
|-------------|----------|---------|------------|--------------|---------|----------|
| **Dev** | East US | Standard_D2s_v3 | 2 | 1-5 nodes | 30GB | Development & Testing |
| **Test** | East US 2 | Standard_D4s_v3 | 3 | 2-8 nodes | 50GB | Integration Testing |
| **Prod** | West US 2 | Standard_D8s_v3 | 5 | 3-10 nodes | 100GB | Production Workloads |

### Deployment Instructions

#### Deploy Development Environment
```bash
cd dev/
terraform init
terraform plan
terraform apply -auto-approve
```

#### Deploy Test Environment  
```bash
cd test/
terraform init
terraform plan
terraform apply -auto-approve
```

#### Deploy Production Environment
```bash
cd prod/
terraform init
terraform plan
terraform apply -auto-approve
```

### Environment-Specific Features

#### **Development Environment**
- **Purpose**: Local development and experimentation
- **Resources**: Minimal resource allocation for cost efficiency
- **Monitoring**: Basic logging enabled
- **ArgoCD**: Single replica with standard resource limits

#### **Test Environment**  
- **Purpose**: Integration testing and staging
- **Resources**: Enhanced VM sizes and node count for testing workloads
- **Monitoring**: Standard monitoring with extended log retention
- **ArgoCD**: Enhanced resource limits for better performance

#### **Production Environment**
- **Purpose**: Production workloads with high availability
- **Resources**: High-performance VMs with maximum scalability
- **Monitoring**: Full monitoring suite with 90-day log retention
- **ArgoCD**: High availability with multiple replicas and production-grade resource allocation

### Backend State Management

Each environment has its own Terraform state file:
- **Dev**: `dev/terraform.tfstate`
- **Test**: `test/terraform.tfstate`  
- **Prod**: `prod/terraform.tfstate`

Configure remote state backend for each environment using the respective `backend.tf.example`:

```bash
# For each environment
cp backend.tf.example backend.tf
# Update with your Azure Storage Account details
```

---

## 🌐 Accessing ArgoCD WebUI

### Get ArgoCD Access Information

```bash
# Get the LoadBalancer external IP
ARGOCD_IP=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "ArgoCD URL: http://$ARGOCD_IP"

# Get the admin password
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
echo "Username: admin"
echo "Password: $ARGOCD_PASSWORD"
```

### Access ArgoCD WebUI

1. **Open your web browser** and navigate to: `http://<EXTERNAL-IP>`

2. **Login credentials:**
   - **Username:** `admin`
   - **Password:** Use the password from the command above

3. **First-time setup:**
   - Change the default admin password
   - Explore the ArgoCD interface
   - Check the "Applications" section

### Alternative: Port Forward (if LoadBalancer IP is not available)

```bash
# Port forward ArgoCD service to localhost
kubectl port-forward svc/argocd-server -n argocd 8080:80

# Access via: http://localhost:8080
# Use same credentials as above
```

---

## 🎯 Quick Application Access


###  Manual Steps

```bash
# 1. Check your deployed applications
kubectl get applications -n argocd

# 2. For the guestbook application, start port forwarding
kubectl port-forward svc/guestbook-ui -n guestbook-dev 8081:80

# 3. Open your browser and navigate to:
# http://localhost:8081
```

**🎉 Your application is now accessible! Try adding some messages to see the guestbook in action.**

---

## 📋 Application Access Summary

### 🎯 Quick Access (Recommended)
```bash
# Use the helper script for easiest access
./access-app.sh
```

### 🔗 All Access Methods

| Method | Use Case | Command | Access URL |
|--------|----------|---------|------------|
| **Port Forward** | Development, Testing | `kubectl port-forward svc/guestbook-ui -n guestbook-dev 8081:80` | `http://localhost:8081` |
| **LoadBalancer** | External Access | `kubectl patch svc guestbook-ui -n guestbook-dev -p '{"spec":{"type":"LoadBalancer"}}'` | `http://<EXTERNAL-IP>` |
| **Ingress** | Production, Custom Domain | Create Ingress resource | `http://guestbook.local` |


### 🚀 Next Steps
1. **Try the Application**: Add some messages to test functionality
2. **Monitor via ArgoCD**: Check sync status and health
3. **Deploy More Apps**: Use the GitOps pattern for your applications  
4. **Scale to Production**: Deploy test and prod environments

---

## 🚀 Deploying Applications

### Option 1: Using Terraform (Automated)

The guestbook appis automatically deployed via the Terraform configuration:

```bash
# Check if application is deployed
kubectl get applications -n argocd

# Check application status
kubectl describe application guestbook-dev -n argocd
```

### Option 2: Manual Application Deployment

```bash
# Create a sample application via ArgoCD CLI or WebUI
kubectl apply -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/your-username/your-app-repo
    targetRevision: HEAD
    path: manifests
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
EOF
```

---

## 🌍 Accessing Deployed Application WebUI

### Check Deployed Applications

```bash
# List all deployed applications
kubectl get applications -n argocd

# Check application details and sync status
kubectl describe application guestbook-dev -n argocd

# Verify application pods and services are running
kubectl get pods,svc -n guestbook-dev

# Expected output:
# NAME                                READY   STATUS    RESTARTS   AGE
# pod/guestbook-ui-85db984648-xxxxx   1/1     Running   0          20m
# 
# NAME                   TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)   AGE
# service/guestbook-ui   ClusterIP   10.0.225.136   <none>        80/TCP    20m
```

### Access Application WebUI

The deployed guestbook application runs as a ClusterIP service by default. Here are three methods to access it:

#### Method 1: Port Forward (Recommended for Development)

```bash
# Start port forwarding for the guestbook application
kubectl port-forward svc/guestbook-ui -n guestbook-dev 8081:80

# Keep this terminal open and open your browser to:
# http://localhost:8081

# You should see the guestbook interface where you can:
# - Add new messages
# - View existing messages
# - See real-time updates
```


#### Method 2: Expose Application via LoadBalancer

For external access without port forwarding:

```bash
# Patch the service to use LoadBalancer type
kubectl patch svc guestbook-ui -n guestbook-dev -p '{"spec":{"type":"LoadBalancer"}}'

# Wait for external IP assignment (may take 2-5 minutes)
echo "Waiting for external IP..."
kubectl get svc guestbook-ui -n guestbook-dev --watch

# Once you see an external IP, access the application:
EXTERNAL_IP=$(kubectl get svc guestbook-ui -n guestbook-dev -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "Access your application at: http://$EXTERNAL_IP"

# To revert back to ClusterIP:
# kubectl patch svc guestbook-ui -n guestbook-dev -p '{"spec":{"type":"ClusterIP"}}'
```

#### Method 3: Expose Application via Ingress (Production Ready)

For production deployments with custom domains:

```bash
# First, install NGINX Ingress Controller (if not already installed)
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/cloud/deploy.yaml

# Wait for ingress controller to be ready
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=90s

# Create an ingress for the application
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: guestbook-ingress
  namespace: guestbook-dev
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
spec:
  ingressClassName: nginx
  rules:
  - host: guestbook.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: guestbook-ui
            port:
              number: 80
EOF

# Get the ingress external IP
INGRESS_IP=$(kubectl get svc ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "Ingress IP: $INGRESS_IP"

# Add to /etc/hosts for local testing
echo "$INGRESS_IP guestbook.local" | sudo tee -a /etc/hosts

# Access via: http://guestbook.local
echo "Access your application at: http://guestbook.local"
```

### Application Features & Testing

The deployed guestbook application provides:

- **📝 Frontend Interface**: Clean, responsive web UI for message management
- **💾 Message Storage**: In-memory storage for demo purposes (messages reset on pod restart)
- **⚡ Real-time Updates**: Messages appear instantly after submission
- **🎨 Simple Design**: Minimalist interface perfect for testing GitOps workflows

### Test Your Application

```bash
# Method 1: Browser Testing
# 1. Open http://localhost:8081 (if using port forwarding)
# 2. Add a test message: "Hello from AKS GitOps!"
# 3. Verify the message appears in the list
# 4. Add multiple messages to test functionality

# Method 2: API Testing (if application supports REST API)
curl -X POST http://localhost:8081/api/messages \
  -H "Content-Type: application/json" \
  -d '{"message": "Hello from curl!"}'

# Method 3: Load Testing (optional)
# Install Apache Bench: sudo apt-get install apache2-utils
ab -n 100 -c 10 http://localhost:8081/
```

### Verify Application Health

```bash
# Check pod status and readiness
kubectl get pods -n guestbook-dev
kubectl describe pod -l app=guestbook-ui -n guestbook-dev

# Check application logs for any issues
kubectl logs -l app=guestbook-ui -n guestbook-dev --tail=50

# Verify service endpoints are working
kubectl get endpoints guestbook-ui -n guestbook-dev

# Test application connectivity from within cluster
kubectl run debug-pod --image=curlimages/curl --rm -it --restart=Never -- \
  curl -s http://guestbook-ui.guestbook-dev.svc.cluster.local

# Health check with port forwarding
kubectl port-forward svc/guestbook-ui -n guestbook-dev 8081:80 &
sleep 3
curl -s http://localhost:8081 | grep -i "guestbook\|welcome\|message" || echo "Application responded"
kill %1  # Stop background port forwarding
```

### Troubleshooting Application Access

#### Common Issues and Solutions

**1. Port Forward Connection Refused**
```bash
# Check if service exists and has endpoints
kubectl get svc,endpoints -n guestbook-dev

# Verify pod is running and ready
kubectl get pods -n guestbook-dev
kubectl logs -l app=guestbook-ui -n guestbook-dev

# Try different local port
kubectl port-forward svc/guestbook-ui -n guestbook-dev 8082:80
```

**2. Application Not Loading in Browser**
```bash
# Check if port forwarding is active
netstat -tulpn | grep :8081
lsof -i :8081

# Test with curl first
curl -v http://localhost:8081

# Check for firewall issues
sudo ufw status
```

**3. LoadBalancer External IP Pending**
```bash
# Check if LoadBalancer service is supported
kubectl describe svc guestbook-ui -n guestbook-dev

# Check Azure Load Balancer configuration
az network lb list --resource-group MC_*

# Fall back to port forwarding
kubectl patch svc guestbook-ui -n guestbook-dev -p '{"spec":{"type":"ClusterIP"}}'
```

**4. Application Shows Error or Empty Page**
```bash
# Check application logs for errors
kubectl logs -l app=guestbook-ui -n guestbook-dev --tail=100

# Restart the application pod
kubectl rollout restart deployment/guestbook-ui -n guestbook-dev

# Check if ArgoCD sync is healthy
kubectl describe application guestbook-dev -n argocd
```

---

## ✅ Verification

### Automated Validation Script

```bash
# Run the deployment validation script
chmod +x validate-deployment.sh
./validate-deployment.sh
```

### Manual Verification Steps

```bash
# 1. Check cluster status
kubectl get nodes
kubectl cluster-info

# 2. Verify ArgoCD components
kubectl get pods -n argocd
kubectl get svc -n argocd

# 3. Check applications
kubectl get applications -n argocd

# 4. Test application access (if Goal Tracker is deployed)
kubectl get pods -n goal-tracker
kubectl get svc -n goal-tracker
```

### Health Indicators ✅

**Healthy deployment should show:**

- All nodes in "Ready" state
- All ArgoCD pods "Running"
- ArgoCD LoadBalancer has external IP
- Applications show "Synced" and "Healthy" status

---

## 🔧 Troubleshooting

### Common Issues and Solutions

#### 1. kubectl Connection Issues

```bash
# Reset kubectl configuration
az aks get-credentials --resource-group <rg-name> --name <cluster-name> --admin --overwrite-existing

# Test connectivity
kubectl get nodes --request-timeout=30s
```

#### 2. ArgoCD UI Not Accessible

```bash
# Check LoadBalancer service
kubectl get svc argocd-server -n argocd

# Use port forwarding as backup
kubectl port-forward svc/argocd-server -n argocd 8080:80
# Access: http://localhost:8080
```

#### 3. Terraform Apply Fails

```bash
# Check Azure authentication
az account show

# Re-initialize Terraform
terraform init -reconfigure

# Check for resource conflicts
terraform plan
```

#### 4. Application Sync Issues

```bash
# Check ArgoCD application status
kubectl describe application <app-name> -n argocd

# Force sync via CLI
kubectl patch application <app-name> -n argocd --type merge --patch '{"operation":{"sync":{"syncStrategy":{"force":true}}}}'
```

---

## 🧹 Clean Up

### Remove Applications

```bash
# Delete all ArgoCD applications
kubectl delete applications --all -n argocd
```

### Remove Infrastructure

```bash
# Destroy the environment
terraform destroy -auto-approve
```

### Clean Up Resources

```bash
# Remove kubectl configuration
kubectl config delete-context <cluster-context>

# Clean up local files
rm -f ~/.kube/config.backup
```

---

## 📝 Configuration Files

### Key Configuration Files

- `terraform.tfvars` - Environment-specific variables
- `main.tf` - AKS cluster configuration
- `kubernetes-resources.tf` - ArgoCD and Kubernetes resources
- `provider.tf` - Terraform provider configuration

### Default Settings

- **Environment:** Development
- **Location:** East US
- **Node Count:** 2 (auto-scaling: 1-5)
- **VM Size:** Standard_D2s_v3
- **ArgoCD:** LoadBalancer with insecure mode (demo)

---

## 🎯 Next Steps

1. **Explore ArgoCD WebUI** - Navigate through applications and sync policies
2. **Deploy Your Applications** - Add your own Git repositories
3. **Set Up Monitoring** - Configure Log Analytics and Azure Monitor
4. **Enable TLS** - Configure HTTPS for ArgoCD in production
5. **Scale to Test/Prod** - Deploy test and production environments

---

## 📞 Support

For issues or questions:

1. Check the troubleshooting section above
2. Review Terraform and kubectl logs
3. Validate Azure permissions and quotas
4. Ensure all prerequisites are met

**🎉 Congratulations! You now have a fully functional AKS GitOps platform!**
