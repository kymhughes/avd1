variable "avdLocation" {
  type        = string
  description = "Azure region"
}

variable "tenant_id" {
  type        = string
  description = "Azure tenant ID."
  default     = null
}

variable "spoke_subscription_id" {
  type        = string
  description = "Spoke subscription ID"
}

variable "hub_subscription_id" {
  type        = string
  description = "Hub subscription ID"
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to supported resources."
  default     = {}
}

variable "rg_storage_name" {
  type        = string
  description = "Storage RG name (from module 01: rg_storage_name)"
}

variable "rg_network" {
  type        = string
  description = "Network resource group name."
}

variable "vnet_name" {
  type        = string
  description = "Spoke virtual network name."
}

variable "pesubnet_files" {
  type        = string
  description = "Azure Files private endpoint subnet name."
}

variable "hub_dns_zone_rg" {
  type        = string
  description = "Hub resource group for private DNS zones"
}

variable "storage_accounts" {
  description = "Storage accounts, Azure Files shares, private endpoint names, and share RBAC assignments."
  type = map(object({
    name                            = string
    managed_identity_name           = string
    kind                            = string
    sku_name                        = string
    identity_auth_directory_service = optional(string, "AADKERB")
    private_endpoint_name           = string
    private_service_connection_name = string
    private_dns_zone_group_name     = string
    private_dns_vnet_link_name      = optional(string)
    shares = map(object({
      name        = string
      quota_gb    = number
      rbac_groups = optional(list(string), [])
    }))
  }))
}
