# Improved AKS Configuration with Best Practices
# This prevents the "Provider produced inconsistent result" error

# Data source to get current Azure client configuration
data "azurerm_client_config" "current" {}

locals {
  resource_name_prefix = "${var.environment}-${random_string.suffix.result}"
  common_tags          = merge(var.tags, { Environment = var.environment })

  # Use a deterministic node resource group name
  # This prevents circular dependencies
  infra_nodes_rg_name = "${var.kubernetes_cluster_name}-${var.environment}-nodes"
}

# Random String for Suffix
resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false

  # Add lifecycle rule to prevent recreation
  lifecycle {
    ignore_changes = [length, special, upper]
  }
}

# Resource Group with lifecycle management
resource "azurerm_resource_group" "main" {
  name     = "${var.resource_group_name}-${var.environment}"
  location = var.location
  tags     = local.common_tags

  # Prevent accidental deletion
  lifecycle {
    prevent_destroy = true
  }
}

# AKS cluster with improved configuration
resource "azurerm_kubernetes_cluster" "main" {
  name                = "${var.kubernetes_cluster_name}-${var.environment}"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  dns_prefix          = "${var.kubernetes_cluster_name}-${var.environment}"

  # Use explicit node resource group name
  node_resource_group = local.infra_nodes_rg_name
  kubernetes_version  = var.kubernetes_version

  # Add timeouts for long operations
  timeouts {
    create = "30m"
    update = "30m"
    delete = "30m"
  }

  default_node_pool {
    name                        = "default"
    node_count                  = var.node_count
    os_disk_size_gb             = 30
    vm_size                     = var.vm_size
    temporary_name_for_rotation = "tmpdefault"

    # Enable auto-scaling for better reliability
    enable_auto_scaling = true
    min_count           = 1
    max_count           = 5
  }

  # Conditional SSH key configuration
  dynamic "linux_profile" {
    for_each = fileexists("~/.ssh/id_rsa_azure.pub") ? [1] : []
    content {
      admin_username = "azureuser"
      ssh_key {
        key_data = file("~/.ssh/id_rsa_azure.pub")
      }
    }
  }

  identity {
    type = "SystemAssigned"
  }

  azure_active_directory_role_based_access_control {
    tenant_id          = data.azurerm_client_config.current.tenant_id
    azure_rbac_enabled = true
  }

  key_vault_secrets_provider {
    secret_rotation_enabled = true
  }

  # Network configuration for better stability
  network_profile {
    network_plugin = "azure"
    network_policy = "azure"
  }

  # Ignore changes to kubernetes_version to prevent unwanted upgrades
  lifecycle {
    ignore_changes = [
      kubernetes_version,
      default_node_pool[0].orchestrator_version
    ]
    prevent_destroy = true
  }

  tags = local.common_tags
}

# Wait for cluster to be fully ready before proceeding
resource "time_sleep" "wait_for_cluster" {
  depends_on      = [azurerm_kubernetes_cluster.main]
  create_duration = "60s"
}
