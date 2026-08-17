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
    http = {
      source  = "hashicorp/http"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.9.0"
    }
  }
}



provider "azurerm" {
  alias                           = "spoke"
  subscription_id                 = var.spoke_subscription_id
  storage_use_azuread             = true
  resource_provider_registrations = "none"
  features {
    key_vault {}
  }
}

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
