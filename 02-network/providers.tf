terraform {
  required_version = ">= 1.6.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
}

provider "azurerm" {
  alias = "remote"
  #subscription_id = var.remote_subscription_id
  #tenant_id       = var.remote_tenant_id
  features {}
}
