# GitOps Terraform Deployment - Quick Start Guide

## 🚀 What Was Created

Your complete GitOps infrastructure includes:

### Infrastructure (Terraform)
- **3 AKS Clusters**: Separate clusters for dev, test, and prod
- **3 Resource Groups**: Isolated environments with dedicated state files
- **Managed Identity Authentication**: Secure Azure resource access
- **ArgoCD Installation**: Automated GitOps controller in each cluster
- **Log Analytics**: Integrated monitoring for all clusters
- **Networking**: LoadBalancers for external access

### Application Configuration (GitOps)
- **Base Manifests**: Kubernetes YAML for Goal Tracker app
- **Environment Overlays**: Dev/test/prod specific configurations
- **Kustomize Structure**: Clean separation of base and environment configs

### Docker Images Expected
- `itsbaivab/frontend:latest` - React frontend
- `itsbaivab/backend:latest` - Backend API
- `postgres:15` - Database (pulled automatically)

## 📁 Directory Structure

```
day28/
├── dev/                    # Dev environment (eastus3, 2 nodes)
├── test/                   # Test environment (eastus2, 2 nodes)  
├── prod/                   # Prod environment (westus2, 3 nodes)
├── gitops-configs/         # GitOps repository content
├── docker-local-deployment/ # Local development setup
├── deploy.sh*              # Automated deployment script
├── validate.sh*            # Validation and status script
├── cleanup.sh*             # Infrastructure cleanup script
└── README.md               # Complete documentation
```

## ⚡ Quick Deployment

### 1. Prerequisites Check
```bash
# Ensure you have:
az login
terraform --version
kubectl version --client
```

### 2. Deploy Everything
```bash
./deploy.sh
# Choose option 1 to deploy all environments
```

### 3. Validate Deployment
```bash
./validate.sh
# Check all environments are healthy
```

### 4. Setup GitOps Repository
```bash
# Create repository on GitHub named 'gitops-configs'
# Copy gitops-configs/ contents to the new repository
# Push to GitHub
```

## 🔧 Environment Differences

| Environment | Region   | Nodes | VM Size | App Replicas |
|-------------|----------|-------|---------|--------------|
| **Dev**     | eastus3  | 2     | D2s_v3  | 1/1          |
| **Test**    | eastus2  | 2     | D2s_v3  | 2/2          |
| **Prod**    | westus2  | 3     | D4s_v3  | 3/3          |

## 🌐 Access Your Applications

After deployment, get access URLs:

```bash
# ArgoCD URLs (admin/password from validate.sh)
kubectl get svc argocd-server -n argocd

# Application URLs
kubectl get svc frontend -n goal-tracker

# Or use the validate script for all info
./validate.sh
```

## 📋 What Happens During Deployment

1. **Terraform Creates**:
   - AKS clusters with RBAC enabled
   - System-assigned managed identities
   - Node pools with specified VM sizes

2. **ArgoCD Installation**:
   - Helm chart deployment
   - LoadBalancer service for external access
   - Application definition for Goal Tracker

3. **Application Deployment**:
   - ArgoCD syncs from your GitHub repository
   - Deploys frontend, backend, and PostgreSQL
   - Creates LoadBalancers for external access

## 🔍 Monitoring & Troubleshooting

### Check Status
```bash
# Cluster status
kubectl get nodes

# ArgoCD applications
kubectl get applications -n argocd

# Application pods
kubectl get pods -n goal-tracker

# Application logs
kubectl logs -f deployment/frontend -n goal-tracker
```

### Common Issues
1. **Images not found**: Ensure Docker images are pushed to DockerHub
2. **ArgoCD sync failed**: Check repository URL and permissions
3. **Pods pending**: Check node resources and quotas

## 🧹 Cleanup

When done testing:
```bash
./cleanup.sh
# Choose option 1 to destroy all environments
```

## 🎯 Next Steps

1. **Push Docker Images**:
   ```bash
   docker push itsbaivab/frontend:latest
   docker push itsbaivab/backend:latest
   ```

2. **Create GitOps Repository**:
   - Create `gitops-configs` repository on GitHub
   - Push the `gitops-configs/` directory contents

3. **Access Applications**:
   - Use LoadBalancer IPs to access your applications
   - Use ArgoCD UI to monitor deployments

4. **Make Changes**:
   - Update image tags in GitOps repository
   - Watch ArgoCD automatically sync changes

## 🔐 Security Notes

- **Managed Identity**: All environments use Azure managed identity for secure authentication
- **ArgoCD**: Configured with `--insecure` for demo purposes
- **SSH Keys**: Auto-generated if not present (optional for this setup)
- **PostgreSQL**: Uses basic credentials (enhance for production)
- **RBAC**: Azure AD integration enabled on all clusters
- **State Files**: Each environment uses separate remote state files
- **Monitoring**: Log Analytics integration for cluster observability

Your GitOps infrastructure is now ready! 🎉
