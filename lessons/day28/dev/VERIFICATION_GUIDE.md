# 🔍 How to Verify Your AKS GitOps Deployment

## ✅ **GOOD NEWS: Your Deployment is HEALTHY!**

Based on the validation results, here's how to verify your deployment is working:

---

## 🎯 **Quick Health Checks**

### 1. **Check Overall Status**
```bash
# Run the comprehensive validation script
./validate-deployment.sh

# Quick cluster check
kubectl get nodes
kubectl get pods --all-namespaces
```

### 2. **Verify Terraform State**
```bash
# Check if all resources are in state
terraform state list

# Show detailed resource information
terraform show

# Check outputs
terraform output
```

### 3. **Verify AKS Cluster**
```bash
# Check cluster status in Azure
az aks show --name aks-gitops-cluster-dev --resource-group aks-gitops-rg-dev --query "provisioningState"

# Check cluster info
kubectl cluster-info

# Check node status
kubectl get nodes -o wide
```

---

## 🚀 **ArgoCD Verification**

### 1. **Check ArgoCD Components**
```bash
# Check all ArgoCD pods are running
kubectl get pods -n argocd

# Expected output: All pods should be Running or Completed
# - argocd-application-controller-0
# - argocd-applicationset-controller-*
# - argocd-dex-server-*
# - argocd-notifications-controller-*
# - argocd-redis-*
# - argocd-repo-server-*
# - argocd-server-*
```

### 2. **Access ArgoCD UI**
```bash
# Get the LoadBalancer IP
kubectl get svc argocd-server -n argocd

# Expected output shows EXTERNAL-IP
# NAME            TYPE           CLUSTER-IP    EXTERNAL-IP    PORT(S)
# argocd-server   LoadBalancer   10.0.87.109   4.156.110.77   80:30180/TCP,443:32287/TCP

# Access via: http://4.156.110.77
```

### 3. **Get ArgoCD Credentials**
```bash
# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Login details:
# Username: admin
# Password: [output from above command]
```

---

## 📱 **Application Verification**

### 1. **Check ArgoCD Applications**
```bash
# List all applications
kubectl get applications -n argocd

# Check application details
kubectl describe application goal-tracker-dev -n argocd

# Expected status: Sync Status = Synced, Health Status = Healthy
```

### 2. **Check Application Pods**
```bash
# Check if application namespace exists
kubectl get namespace goal-tracker

# Check application pods (if deployed)
kubectl get pods -n goal-tracker
```

---

## 🔧 **Troubleshooting Commands**

### 1. **If ArgoCD UI Not Accessible**
```bash
# Use port forwarding as backup
kubectl port-forward svc/argocd-server -n argocd 8080:80

# Then access: http://localhost:8080
```

### 2. **If Pods Not Running**
```bash
# Check pod logs
kubectl logs -n argocd <pod-name>

# Check pod events
kubectl describe pod -n argocd <pod-name>

# Check all events in namespace
kubectl get events -n argocd --sort-by=.metadata.creationTimestamp
```

### 3. **If Applications Not Syncing**
```bash
# Check application logs
kubectl logs -n argocd deployment/argocd-application-controller

# Check repo server logs
kubectl logs -n argocd deployment/argocd-repo-server

# Force sync application
kubectl patch application goal-tracker-dev -n argocd --type merge --patch '{"operation":{"sync":{"revision":"HEAD"}}}'
```

---

## 📊 **Health Indicators**

### ✅ **Healthy Deployment Indicators:**
- All Terraform resources in state ✅
- AKS cluster status = "Succeeded" ✅  
- All nodes show "Ready" status ✅
- All ArgoCD pods show "Running" status ✅
- LoadBalancer has external IP ✅
- ArgoCD UI accessible ✅
- Applications show "Synced" and "Healthy" ✅

### 🔴 **Red Flags (Issues to Fix):**
- Terraform resources missing from state
- Cluster status not "Succeeded"
- Nodes not in "Ready" state
- ArgoCD pods in "CrashLoopBackOff" or "Pending"
- LoadBalancer stuck in "Pending" state
- Applications showing "OutOfSync" or "Degraded"

---

## 🌐 **Access URLs**

### ArgoCD Web UI:
- **URL**: http://4.156.110.77
- **Username**: admin
- **Password**: 8wmp16MdsYLEcXOo

### Alternative Access (Port Forward):
```bash
kubectl port-forward svc/argocd-server -n argocd 8080:80
# Then: http://localhost:8080
```

---

## 🎯 **Success Metrics**

Your deployment is **WORKING** if:

1. ✅ **Infrastructure**: AKS cluster is running with ready nodes
2. ✅ **GitOps**: ArgoCD is accessible and functional
3. ✅ **Applications**: Can deploy and manage apps via GitOps
4. ✅ **Networking**: LoadBalancer and DNS working
5. ✅ **State**: Terraform state consistent with Azure resources

**Current Status: ALL GREEN! 🎉**
