# outputs.tf
output "aks_cluster_name" {
  description = "Name of the AKS cluster"
  value       = azurerm_kubernetes_cluster.main.name
}

output "aks_cluster_id" {
  description = "ID of the AKS cluster"
  value       = azurerm_kubernetes_cluster.main.id
}

output "kube_config" {
  description = "Kubeconfig for the AKS cluster"
  value       = azurerm_kubernetes_cluster.main.kube_config_raw
  sensitive   = true
}

output "argocd_server_ip" {
  description = "ArgoCD server external IP"
  value       = "Run 'kubectl get svc argocd-server -n argocd' to get the external IP"
}

# Commented out since Log Analytics workspace is optional
# output "log_analytics_workspace_id" {
#   description = "Log Analytics workspace ID"
#   value       = azurerm_log_analytics_workspace.main.id
# }

output "argocd_admin_password" {
  description = "ArgoCD admin password command"
  value       = "Run 'kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath=\"{.data.password}\" | base64 -d' to get the admin password"
}

output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.main.name
}

output "environment" {
  description = "Environment name"
  value       = var.environment
}

# ===============================
# KEY VAULT OUTPUTS
# ===============================

output "key_vault_name" {
  description = "Name of the Key Vault"
  value       = var.enable_key_vault ? azurerm_key_vault.main[0].name : null
}

output "key_vault_id" {
  description = "ID of the Key Vault"
  value       = var.enable_key_vault ? azurerm_key_vault.main[0].id : null
}

output "key_vault_uri" {
  description = "URI of the Key Vault"
  value       = var.enable_key_vault ? azurerm_key_vault.main[0].vault_uri : null
}

# Database secret references (for use in applications)
output "postgres_username_secret_name" {
  description = "Name of the PostgreSQL username secret in Key Vault"
  value       = var.enable_key_vault ? azurerm_key_vault_secret.postgres_username[0].name : null
}

output "postgres_password_secret_name" {
  description = "Name of the PostgreSQL password secret in Key Vault"
  value       = var.enable_key_vault ? azurerm_key_vault_secret.postgres_password[0].name : null
}

output "postgres_database_secret_name" {
  description = "Name of the PostgreSQL database secret in Key Vault"
  value       = var.enable_key_vault ? azurerm_key_vault_secret.postgres_database[0].name : null
}

output "postgres_connection_string_secret_name" {
  description = "Name of the PostgreSQL connection string secret in Key Vault"
  value       = var.enable_key_vault ? azurerm_key_vault_secret.postgres_connection_string[0].name : null
}

# Cluster secret references
output "aks_admin_kubeconfig_secret_name" {
  description = "Name of the AKS admin kubeconfig secret in Key Vault"
  value       = var.enable_key_vault ? azurerm_key_vault_secret.aks_admin_kubeconfig[0].name : null
}

output "cluster_identity_principal_id" {
  description = "Principal ID of the AKS cluster managed identity"
  value       = azurerm_kubernetes_cluster.main.identity[0].principal_id
}

# Instructions for using Key Vault secrets
output "key_vault_access_instructions" {
  description = "Instructions for accessing Key Vault secrets"
  value = var.enable_key_vault ? [
    "To retrieve database password: az keyvault secret show --vault-name ${azurerm_key_vault.main[0].name} --name postgres-password --query value -o tsv",
    "To retrieve kubeconfig: az keyvault secret show --vault-name ${azurerm_key_vault.main[0].name} --name aks-admin-kubeconfig --query value -o tsv > ~/.kube/config-${var.environment}",
    "To list all secrets: az keyvault secret list --vault-name ${azurerm_key_vault.main[0].name} --query '[].name' -o tsv"
  ] : []
}
