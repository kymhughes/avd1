terraform {
  required_version = ">= 1.9.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
  # backend "azurerm" {
  #   resource_group_name  = "rg-terraform-state"
  #   storage_account_name = "sttfstate<suffix>"
  #   container_name       = "tfstate"
  #   key                  = "avd/09-monitoring.tfstate"
  # }
}

provider "azurerm" {
  subscription_id                 = var.spoke_subscription_id
  storage_use_azuread             = true
  resource_provider_registrations = "none"
  features {}
}
