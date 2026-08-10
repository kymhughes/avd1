terraform {
  required_version = ">= 1.9.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
  # Uncomment and configure for ADO pipeline remote state
  # backend "azurerm" {
  #   resource_group_name  = "rg-terraform-state"
  #   storage_account_name = "sttfstate<suffix>"
  #   container_name       = "tfstate"
  #   key                  = "avd/01-resource-groups.tfstate"
  # }
}

provider "azurerm" {
  storage_use_azuread             = true
  resource_provider_registrations = "none"
  features {}
}
provider "azurerm" {
  alias                           = "spoke"
  subscription_id                 = var.spoke_subscription_id
  storage_use_azuread             = true
  resource_provider_registrations = "none"
  features {}
}

provider "azurerm" {
  alias                           = "hub"
  subscription_id                 = var.hub_subscription_id
  storage_use_azuread             = true
  resource_provider_registrations = "none"
  features {}
}