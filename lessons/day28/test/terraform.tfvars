environment             = "test"
location                = "eastus"
resource_group_name     = "aks-gitops-rg"
kubernetes_cluster_name = "aks-gitops-cluster"
vm_size                 = "Standard_D4s_v3" # Upgraded VM size for test
kubernetes_version      = "1.32.5"
gitops_repo_url         = "https://github.com/itsbaivab/gitops-configs.git"
argocd_namespace        = "argocd"
app_repo_url            = "https://github.com/argoproj/argocd-example-apps.git"
app_repo_path           = "guestbook"

tags = {
  Environment = "test"
  Project     = "AKS-GitOps"
  ManagedBy   = "Terraform"
}
