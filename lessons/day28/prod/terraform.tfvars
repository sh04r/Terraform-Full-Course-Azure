environment             = "prod"
location                = "eastus"
resource_group_name     = "aks-gitops-rg"
kubernetes_cluster_name = "aks-gitops-cluster"
vm_size                 = "Standard_D8s_v3" # Upgraded VM size for production (8 vCPUs, 32GB RAM)
kubernetes_version      = "1.32.5"
gitops_repo_url         = "https://github.com/itsbaivab/gitops-configs.git"
argocd_namespace        = "argocd"

tags = {
  Environment = "production"
  Project     = "AKS-GitOps"
  ManagedBy   = "Terraform"
}
