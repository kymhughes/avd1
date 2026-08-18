terraform {
  required_version = ">= 1.9.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.78.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.9.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.9.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
    azapi = {
      source = "Azure/azapi"
      version = "~> 2.0"
    }
  }
  # backend "azurerm" {
  #   resource_group_name  = "rg-terraform-state"
  #   storage_account_name = "sttfstate<suffix>"
  #   container_name       = "tfstate"
  #   key                  = "avd/05-avd-hostpool.tfstate"
  # }
}

provider "azurerm" {
  subscription_id                 = var.spoke_subscription_id
  storage_use_azuread             = true
  resource_provider_registrations = "none"
  features {}
}

# Hub provider — read-only, used only for data blocks (private DNS zones)
provider "azurerm" {
  alias                           = "hub"
  subscription_id                 = var.hub_subscription_id
  storage_use_azuread             = true
  resource_provider_registrations = "none"
  features {}
}

provider "azuread" {
  tenant_id = var.tenant_id
  use_cli   = true
}
provider "azapi" {}