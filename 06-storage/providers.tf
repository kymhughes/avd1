terraform {
  required_version = ">= 1.9.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.78.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.9.0"
    }
  }
  # backend "azurerm" {
  #   resource_group_name  = "rg-terraform-state"
  #   storage_account_name = "sttfstate<suffix>"
  #   container_name       = "tfstate"
  #   key                  = "avd/06-storage.tfstate"
  # }
}

provider "azurerm" {
  alias           = "spoke"
  subscription_id = var.spoke_subscription_id
  storage_use_azuread             = true
  resource_provider_registrations = "none"
  features {}
}

provider "azurerm" {
  alias           = "hub"
  subscription_id = var.hub_subscription_id
  storage_use_azuread             = true
  resource_provider_registrations = "none"
  features {}
}
