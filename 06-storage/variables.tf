variable "avdLocation" {
  type        = string
  description = "Azure region"
}

variable "prefix" {
  type        = string
  description = "Short prefix, max 4 chars, lowercase"
}

variable "environment" {
  type        = string
  description = "dev | test | prod"
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

variable "enable_telemetry" {
  type        = bool
  description = "Enable telemetry for AVM modules."
  default     = true
}

variable "rg_storage_name" {
  type        = string
  description = "Storage RG name (from module 01: rg_storage_name)"
}

variable "storage_account_name" {
  type        = string
  description = "Name of the FSLogix storage account."
}

variable "storage_managed_identity_name" {
  type        = string
  description = "Name of the user-assigned managed identity for the storage account."
}

variable "fslogix_share_name" {
  type        = string
  description = "Name of the FSLogix Azure Files share."
  default     = "fslogix"
}

variable "avd_users_group" {
  type        = string
  description = "Display name of the group granted SMB access to the FSLogix file share."
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

variable "file_private_dns_vnet_link_name" {
  type        = string
  description = "Name of the private DNS zone virtual network link for Azure Files."
}

variable "file_private_endpoint_name" {
  type        = string
  description = "Name of the Azure Files private endpoint."
}

variable "file_private_service_connection_name" {
  type        = string
  description = "Name of the Azure Files private service connection."
}

variable "file_private_dns_zone_group_name" {
  type        = string
  description = "Name of the Azure Files private endpoint DNS zone group."
}

variable "fslogix_share_quota_gb" {
  type        = number
  default     = 100
  description = "FSLogix file share quota in GB"
}
