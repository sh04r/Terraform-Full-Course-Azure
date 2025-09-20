# Configure the Azure provider, you can have many
# if you use azurerm provider, it's source is hashicorp/azurerm
# short for registry.terraform.io/hashicorp/azurerm


terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.8.0"
    }
  }

  required_version = ">= 1.9.0"
}
# configures the provider

provider "azurerm" {
  subscription_id = "c12c9f13-38c0-45db-9408-98f2982a27d0"
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}