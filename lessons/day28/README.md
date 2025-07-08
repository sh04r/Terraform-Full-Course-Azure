# 🚀 AKS GitOps Deployment Guide

**Complete step-by-step guide to deploy AKS with GitOps using Terraform and ArgoCD**

This repository provides a production-ready setup for deploying applications to Azure Kubernetes Service (AKS) using GitOps principles with ArgoCD and Terraform.

## 📋 Table of Contents

- [Architecture Overview](#-architecture-overview)
- [Prerequisites](#-prerequisites)
- [🔄 Complete Recreation Guide](#-complete-recreation-guide)
- [Quick Start](#-quick-start)
- [Multi-Environment Setup](#-multi-environment-setup)
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

## 🔄 Complete Recreation Guide

### **⚠️ CRITICAL: Follow this exact sequence for successful recreation**

**Before deploying ANY infrastructure, you MUST first set up your GitOps repository. ArgoCD will fail to deploy applications without access to the manifest files.**

---

### 🎯 Step 1: Create Your GitOps Repository (FIRST!)

#### 1.1 Create New GitHub Repository

1. **Go to GitHub.com** and create a new repository:
   - **Repository name**: `gitops-configs` (or your preferred name)
   - **Description**: "Kubernetes manifests for 3-tier application GitOps deployment"
   - **Visibility**: Public (recommended) or Private with proper access configured
   - ✅ **Initialize with README**

2. **Clone your new repository**:
   ```bash
   # Replace YOUR_USERNAME with your GitHub username
   git clone https://github.com/YOUR_USERNAME/gitops-configs.git
   cd gitops-configs
   ```

#### 1.2 Copy and Push Manifest Files

```bash
# From this project's directory, copy the 3-tier application manifests
# Make sure you're in the root of this project first
cd Terraform-Full-Course-Azure/lessons/day28

# Copy all manifest files to your GitOps repository
cp -r manifest-files/* /path/to/your/gitops-configs/

# Or if you're already in the gitops-configs directory:
# cp /path/to/this/project/manifest-files/3tire-configs/* .

# Navigate to your GitOps repository
cd /path/to/your/gitops-configs

# Verify the files are copied correctly
ls -la
.
├── 3tire-configs
│   ├── argocd-application.yaml
│   ├── backend-config.yaml
│   ├── backend.yaml
│   ├── frontend-config.yaml
│   ├── frontend.yaml
│   ├── kustomization.yaml
│   ├── namespace.yaml
│   ├── postgres-config.yaml
│   ├── postgres-pvc.yaml
│   └── postgres.yaml
```

#### 1.3 Update Repository URL in Manifest Files

**CRITICAL: Update the ArgoCD application to point to YOUR repository:**

```bash
# Edit the ArgoCD application manifest
vim argocd-application.yaml

# Find this line (around line 11):
# repoURL: https://github.com/itsBaivab/gitops-configs.git

# Change it to YOUR repository:
# repoURL: https://github.com/YOUR_USERNAME/gitops-configs.git

# Save and exit (:wq in vim)
```

#### 1.4 Commit and Push to Your GitOps Repository

```bash
# Add all manifest files
git add .

# Commit with a descriptive message
git commit -m "ANY COMMIT OF YOUR CHOICE"

# Push to GitHub
git push origin main
```

#### 1.5 Verify Your GitOps Repository

```bash
# Verify your repository is accessible
curl -s https://api.github.com/repos/YOUR_USERNAME/gitops-configs

---

### 🔧 Step 2: Update Terraform Configuration Files

#### 2.1 Update Repository URLs in ALL Environment Files

**You must update ALL three environment configurations:**

```bash
# Navigate back to the project directory
cd /home/baivab/repos/Terraform-Full-Course-Azure/lessons/day28

# Update Development Environment
vim dev/terraform.tfvars
# Find line ~15: app_repo_url = "https://github.com/itsBaivab/gitops-configs.git"
# Change to:     app_repo_url = "https://github.com/YOUR_USERNAME/gitops-configs.git"

# Update Test Environment  
vim test/terraform.tfvars
# Find line ~15: app_repo_url = "https://github.com/itsBaivab/gitops-configs.git"
# Change to:     app_repo_url = "https://github.com/YOUR_USERNAME/gitops-configs.git"

# Update Production Environment
vim prod/terraform.tfvars  
# Find line ~15: app_repo_url = "https://github.com/itsBaivab/gitops-configs.git"
# Change to:     app_repo_url = "https://github.com/YOUR_USERNAME/gitops-configs.git"
```

#### 2.2 Verify All Repository URLs Are Updated



#### 2.3 Optional: Customize Resource Names

```bash
# If you want to use custom resource group and cluster names:
# Edit each terraform.tfvars file and modify:

# resource_group_name     = "my-custom-aks-rg"
# kubernetes_cluster_name = "my-custom-aks-cluster"

# Note: Keep environment naming consistent across dev/test/prod
```

---

### ✅ Step 3: Validation Before Infrastructure Deployment

#### 3.1 Validate GitOps Repository Access

```bash
# Test that your GitOps repository is publicly accessible
curl -s https://raw.githubusercontent.com/YOUR_USERNAME/gitops-configs/main/namespace.yaml

# This should return the namespace.yaml content. If you get a 404, check:
# 1. Repository name is correct
# 2. Repository is public OR you have access tokens configured
# 3. Files were pushed to the main branch
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

### Manual Steps

```bash
# 1. Check your deployed applications
kubectl get applications -n argocd

# 2. For the 3-tier web application, start port forwarding to frontend
kubectl port-forward svc/frontend -n 3tirewebapp-dev 3000:3000

# 3. Open your browser and navigate to:
# http://localhost:3000
```

**🎉 Your 3-tier application is now accessible! This includes a React frontend, Node.js backend, and PostgreSQL database.**

---

## 📋 Application Access Summary

### 🎯 Quick Access (Recommended)
```bash
# Port forward to frontend service for immediate access
kubectl port-forward svc/frontend -n 3tirewebapp-dev 3000:3000
```

### 🔗 All Access Methods for Your 3-Tier Application

| Method | Use Case | Prerequisites | Command/Steps | Access URL |
|--------|----------|---------------|---------------|------------|
| **Port Forward** | Development, Testing | kubectl access | `kubectl port-forward svc/frontend -n 3tirewebapp-dev 3000:3000` | `http://localhost:3000` |
| **Ingress (Built-in)** | Production-like, Domain Access | NGINX Ingress Controller + /etc/hosts | Install NGINX Ingress + configure hosts file | `http://3tirewebapp-dev.local` |
| **LoadBalancer** | External Cloud Access | Azure LoadBalancer support | Patch service to LoadBalancer type | `http://<EXTERNAL-IP>:3000` |
| **NodePort** | Direct Node Access | Node IP access | Patch service to NodePort type | `http://<NODE-IP>:<NodePort>` |

#### 🏆 Recommended Access Methods by Environment

- **Development**: Port Forward (fastest setup)
- **Testing/Staging**: Built-in Ingress (production-like)
- **Production**: Ingress with real domain + TLS
- **Demo/External**: LoadBalancer (public access)

### 🌐 Using the Built-in Ingress (Recommended for Production-like Testing)

Your manifest already includes an Ingress configuration! Here's how to use it:

#### 📋 Your Ingress Configuration

Your `frontend.yaml` manifest includes this built-in Ingress resource:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: frontend-ingress
  namespace: 3tirewebapp-dev
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
    - host: 3tirewebapp-dev.local
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: frontend
                port:
                  number: 3000
```

**Key Features:**
- **Host**: `3tirewebapp-dev.local` (customizable domain for local testing)
- **Path**: `/` (root path routing to frontend)
- **Target Service**: `frontend` service on port `3000`
- **Ingress Class**: `nginx` (requires NGINX Ingress Controller)
- **Rewrite Target**: Root path rewriting for clean URLs
- **Path Type**: `Prefix` matching for flexible routing

#### Step 1: Install NGINX Ingress Controller

```bash
# Install NGINX Ingress Controller
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/cloud/deploy.yaml

# Wait for ingress controller to be ready
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=90s

# Check ingress controller service
kubectl get svc -n ingress-nginx
```

#### Step 2: Configure Local Domain (for local testing)

```bash
# Get the ingress external IP
INGRESS_IP=$(kubectl get svc ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "Ingress IP: $INGRESS_IP"

# Add to /etc/hosts for local domain resolution
echo "$INGRESS_IP 3tirewebapp-dev.local" | sudo tee -a /etc/hosts

# Verify the ingress is working
kubectl get ingress -n 3tirewebapp-dev
```

#### Step 3: Access via Domain

```bash
# Open your browser to:
# http://3tirewebapp-dev.local

# Or test with curl
curl -H "Host: 3tirewebapp-dev.local" http://$INGRESS_IP
```

### 🚀 Alternative Access Methods

#### Method 1: LoadBalancer (External Cloud Access)

```bash
# Patch the frontend service to use LoadBalancer type
kubectl patch svc frontend -n 3tirewebapp-dev -p '{"spec":{"type":"LoadBalancer"}}'

# Wait for external IP assignment (may take 2-5 minutes)
echo "Waiting for external IP..."
kubectl get svc frontend -n 3tirewebapp-dev --watch

# Get the external IP and access your application
EXTERNAL_IP=$(kubectl get svc frontend -n 3tirewebapp-dev -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "Access your application at: http://$EXTERNAL_IP:3000"

# To revert back to ClusterIP:
kubectl patch svc frontend -n 3tirewebapp-dev -p '{"spec":{"type":"ClusterIP"}}'
```

#### Method 2: NodePort (Direct Node Access)

```bash
# Patch the frontend service to use NodePort type
kubectl patch svc frontend -n 3tirewebapp-dev -p '{"spec":{"type":"NodePort"}}'

# Get the NodePort and Node IP
NODE_PORT=$(kubectl get svc frontend -n 3tirewebapp-dev -o jsonpath='{.spec.ports[0].nodePort}')
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[0].address}')

echo "Access your application at: http://$NODE_IP:$NODE_PORT"

# To revert back to ClusterIP:
kubectl patch svc frontend -n 3tirewebapp-dev -p '{"spec":{"type":"ClusterIP"}}'
```

### 🔍 Your 3-Tier Application Architecture

Your deployed application consists of:

#### **Frontend (React Application)**
- **Service**: `frontend` on port 3000 (ClusterIP)
- **Container**: `itsbaivab/frontend:v2`
- **Features**: React-based web interface with Express.js proxy server
- **Ingress**: Pre-configured with domain `3tirewebapp-dev.local`
- **Health Checks**: HTTP probes on `/` endpoint with liveness/readiness checks
- **Resources**: 100m CPU request, 200m CPU limit, 128Mi-256Mi memory

#### **Backend (Node.js API)**
- **Service**: `backend` on port 8080 (ClusterIP)
- **Container**: `itsbaivab/backend:latest`
- **Database Connection**: Connects to PostgreSQL via ConfigMap/Secret settings
- **API Endpoints**: Health check on `/health`, business logic APIs
- **Frontend Integration**: Backend URL configured as `http://backend:8080`
- **Resources**: 100m CPU request, 200m CPU limit, 128Mi-256Mi memory

#### **Database (PostgreSQL)**
- **Service**: `postgres` on port 5432 (ClusterIP)
- **Container**: `postgres:15`
- **Persistence**: Uses `postgres-pvc` persistent volume for data storage
- **Database**: `goalsdb` with user `postgres`
- **Configuration**: Environment variables managed via ConfigMaps and Secrets

### 🎯 Application Flow Testing

```bash
# 1. Test Frontend Access
kubectl port-forward svc/frontend -n 3tirewebapp-dev 3000:3000 &
curl -s http://localhost:3000 | grep -i "title\|app" || echo "Frontend responded"

# 2. Test Backend API
kubectl port-forward svc/backend -n 3tirewebapp-dev 8080:8080 &
curl -s http://localhost:8080/health || echo "Backend health check"

# 3. Test Database Connection (from within cluster)
kubectl exec -it deployment/backend -n 3tirewebapp-dev -- \
  psql -h postgres -U postgres -d goalsdb -c "SELECT version();"

# Stop background port forwards
kill %1 %2
```


### 🚀 Next Steps
1. **Try the Application**: Add some messages to test functionality
2. **Monitor via ArgoCD**: Check sync status and health
3. **Deploy More Apps**: Use the GitOps pattern for your applications  
4. **Scale to Production**: Deploy test and prod environments

## 🌐 Frontend Ingress Configuration Summary

Your 3-tier application includes a **production-ready ingress configuration** with the following features:

### **🔧 Built-in Ingress Features**
- **Pre-configured Domain**: `3tirewebapp-dev.local` (customizable for your environment)
- **NGINX Ingress Controller**: Uses industry-standard `nginx` ingress class
- **Path-based Routing**: Root path (`/`) routes to frontend service
- **Clean URL Rewriting**: Automatic path rewriting for seamless user experience
- **Service Integration**: Direct connection to `frontend` service on port `3000`

### **🚀 Access Methods Comparison**

| Method | Best For | Setup Time | External Access | Domain Name | Production Ready |
|--------|----------|------------|-----------------|-------------|------------------|
| **Port Forward** | Development & Testing | Immediate | No | localhost | No |
| **Ingress** | Staging & Production | 5 minutes | Yes | Custom domain | ✅ Yes |
| **LoadBalancer** | Cloud demos | 3 minutes | Yes | IP address | Partial |
| **NodePort** | Local clusters | 1 minute | Limited | IP:Port | No |

### **🔐 Production Considerations**

For production deployment, consider these enhancements:
- **TLS/SSL**: Add `tls` section to ingress for HTTPS
- **Real Domain**: Replace `3tirewebapp-dev.local` with your actual domain
- **WAF Integration**: Use cloud WAF services for additional security
- **Rate Limiting**: Configure ingress annotations for rate limiting
- **Health Checks**: Ingress controller monitors pod health automatically

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

## 🌍 Accessing Your 3-Tier Web Application

### Check Deployed Applications

```bash
# List all deployed applications
kubectl get applications -n argocd

# Check application details and sync status
kubectl describe application 3tirewebapp-dev -n argocd

# Verify application pods and services are running
kubectl get pods,svc -n 3tirewebapp-dev

# Expected output:
# NAME                                READY   STATUS    RESTARTS   AGE
# pod/backend-xxxxxxxxxx-xxxxx        1/1     Running   0          20m
# pod/frontend-xxxxxxxxx-xxxxx        1/1     Running   0          20m  
# pod/postgres-xxxxxxxxx-xxxxx        1/1     Running   0          20m
# 
# NAME               TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)    AGE
# service/backend    ClusterIP   10.0.225.136   <none>        8080/TCP   20m
# service/frontend   ClusterIP   10.0.225.137   <none>        3000/TCP   20m
# service/postgres   ClusterIP   10.0.225.138   <none>        5432/TCP   20m
```

### Access Your 3-Tier Application

Your deployed 3-tier application runs with ClusterIP services by default, which provides internal cluster communication. Here are multiple methods to access it externally:

#### Method 1: Port Forward to Frontend (Recommended for Development)

```bash
# Start port forwarding for the frontend application
kubectl port-forward svc/frontend -n 3tirewebapp-dev 3000:3000

# Keep this terminal open and open your browser to:
# http://localhost:3000

# This provides access to your complete 3-tier stack:
# ✅ React frontend (served by Express.js at localhost:3000)
# ✅ Node.js backend API (proxied via frontend at /api/* routes)  
# ✅ PostgreSQL database (connected via backend)
```

#### Method 2: Using the Built-in Ingress (Production-like Access)

Your application already includes an Ingress configuration for domain-based access:

```bash
# 1. Install NGINX Ingress Controller (if not already installed)
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/cloud/deploy.yaml

# 2. Wait for ingress controller to be ready
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=90s

# 3. Get ingress external IP (may take 2-5 minutes)
INGRESS_IP=$(kubectl get svc ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "Ingress IP: $INGRESS_IP"

# 4. Configure local domain resolution for testing
echo "$INGRESS_IP 3tirewebapp-dev.local" | sudo tee -a /etc/hosts

# 5. Access via domain in your browser:
# http://3tirewebapp-dev.local
echo "✅ Access your application at: http://3tirewebapp-dev.local"
```

#### Method 3: Expose Frontend via LoadBalancer (External Cloud Access)

For direct external cloud access without domain configuration:

```bash
# Patch the frontend service to use LoadBalancer type
kubectl patch svc frontend -n 3tirewebapp-dev -p '{"spec":{"type":"LoadBalancer"}}'

# Wait for external IP assignment (may take 2-5 minutes)
echo "⏳ Waiting for external IP assignment..."
kubectl get svc frontend -n 3tirewebapp-dev --watch

# Once you see an external IP, access the application:
EXTERNAL_IP=$(kubectl get svc frontend -n 3tirewebapp-dev -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "✅ Access your application at: http://$EXTERNAL_IP:3000"

# To revert back to ClusterIP (cleanup):
kubectl patch svc frontend -n 3tirewebapp-dev -p '{"spec":{"type":"ClusterIP"}}'
```

### Application Architecture & Features

Your deployed 3-tier application provides:

#### **🎨 Frontend (React + Express.js)**
- **Port**: 3000
- **Architecture**: React app served by Express.js proxy server
- **Backend Integration**: Communicates with Node.js API via `/api/*` routes
- **Ingress Ready**: Pre-configured for domain-based access at `3tirewebapp-dev.local`
- **Health Checks**: HTTP probes on `/` endpoint for kubernetes monitoring
- **Features**: Modern React-based web interface with API proxy functionality

#### **🔧 Backend (Node.js API)**
- **Port**: 8080  
- **Architecture**: RESTful API server with Express.js framework
- **Database Integration**: Connects to PostgreSQL using environment variables
- **Health Endpoint**: Provides `/health` endpoint for monitoring and probes
- **Configuration**: Database connection managed via ConfigMaps and Secrets
- **Features**: Full CRUD operations, database connectivity, health monitoring

#### **🗄️ Database (PostgreSQL)**
- **Port**: 5432
- **Version**: PostgreSQL 15
- **Database**: `goalsdb` with user `postgres`
- **Persistence**: Persistent volume claim ensures data survives pod restarts
- **Configuration**: Connection parameters managed via ConfigMaps and Secrets
- **Features**: Full relational database with ACID compliance

### Test Your 3-Tier Application

```bash
# Method 1: Frontend Browser Testing (Recommended)
# 1. Use port forwarding: kubectl port-forward svc/frontend -n 3tirewebapp-dev 3000:3000
# 2. Open browser to: http://localhost:3000
# 3. Test the web interface functionality
# 4. Verify frontend-backend communication through UI interactions
# 5. Check database interactions via application features

# Method 2: API Testing (Backend Direct)
kubectl port-forward svc/backend -n 3tirewebapp-dev 8080:8080 &
echo "Testing backend health endpoint..."
curl -X GET http://localhost:8080/health
echo "Testing backend API endpoints..."
curl -X GET http://localhost:8080/api/goals  # or your specific API endpoints
kill %1  # Stop background port forwarding

# Method 3: Database Connection Testing (Internal)
echo "Testing database connectivity from backend pod..."
kubectl exec -it deployment/backend -n 3tirewebapp-dev -- \
  psql -h postgres -U postgres -d goalsdb -c "SELECT version();"

# Method 4: Full Stack Communication Test
kubectl run debug-pod --image=curlimages/curl --rm -it --restart=Never -- \
  curl -s http://frontend.3tirewebapp-dev.svc.cluster.local:3000
```

### Verify Application Health & Communication

```bash
# Check all pods are running and ready
kubectl get pods -n 3tirewebapp-dev
kubectl describe pods -n 3tirewebapp-dev

# Check application logs
kubectl logs deployment/frontend -n 3tirewebapp-dev --tail=50
kubectl logs deployment/backend -n 3tirewebapp-dev --tail=50
kubectl logs deployment/postgres -n 3tirewebapp-dev --tail=50

# Verify service endpoints
kubectl get endpoints -n 3tirewebapp-dev

# Test internal service communication
kubectl run debug-pod --image=curlimages/curl --rm -it --restart=Never -- \
  curl -s http://frontend.3tirewebapp-dev.svc.cluster.local:3000

kubectl run debug-pod --image=curlimages/curl --rm -it --restart=Never -- \
  curl -s http://backend.3tirewebapp-dev.svc.cluster.local:8080/health
```

### Troubleshooting Application Access

#### Common Issues and Solutions

**1. Frontend Port Forward Connection Refused**
```bash
# Check if frontend service exists and has endpoints
kubectl get svc,endpoints frontend -n 3tirewebapp-dev

# Verify frontend pod is running and ready
kubectl get pods -l app=frontend -n 3tirewebapp-dev
kubectl logs deployment/frontend -n 3tirewebapp-dev

# Try different local port
kubectl port-forward svc/frontend -n 3tirewebapp-dev 3001:3000
```

**2. Application Shows Backend Connection Error**
```bash
# Check backend service connectivity
kubectl get svc backend -n 3tirewebapp-dev
kubectl get pods -l app=backend -n 3tirewebapp-dev

# Verify backend configuration
kubectl describe configmap frontend-config -n 3tirewebapp-dev
kubectl describe configmap backend-config -n 3tirewebapp-dev

# Test backend API directly
kubectl port-forward svc/backend -n 3tirewebapp-dev 8080:8080 &
curl -v http://localhost:8080/health
kill %1
```

**3. Database Connection Issues**
```bash
# Check PostgreSQL pod and service
kubectl get pods -l app=postgres -n 3tirewebapp-dev
kubectl get svc postgres -n 3tirewebapp-dev

# Check database credentials and configuration
kubectl describe secret postgres-secret -n 3tirewebapp-dev
kubectl describe configmap postgres-config -n 3tirewebapp-dev

# Test database connection from backend pod
kubectl exec -it deployment/backend -n 3tirewebapp-dev -- \
  nc -z postgres 5432 && echo "Database reachable" || echo "Database unreachable"
```

**4. Ingress Domain Not Resolving**
```bash
# Check if ingress controller is running
kubectl get pods -n ingress-nginx
kubectl get svc -n ingress-nginx

# Verify ingress resource
kubectl get ingress -n 3tirewebapp-dev
kubectl describe ingress frontend-ingress -n 3tirewebapp-dev

# Check /etc/hosts entry
grep "3tirewebapp-dev.local" /etc/hosts

# Test with curl using Host header
curl -H "Host: 3tirewebapp-dev.local" http://<INGRESS-IP>
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
