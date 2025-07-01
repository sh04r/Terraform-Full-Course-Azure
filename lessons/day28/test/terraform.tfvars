environment             = "test"
location                = "eastus2"
resource_group_name     = "aks-gitops-rg"
kubernetes_cluster_name = "aks-gitops-cluster"
node_count              = 2
vm_size                 = "Standard_D2s_v3"
kubernetes_version      = "1.32.5"
gitops_repo_url         = "https://github.com/itsbaivab/gitops-configs.git"
argocd_namespace        = "argocd"

tags = {
  Environment = "test"
  Project     = "AKS-GitOps"
  ManagedBy   = "Terraform"
}
