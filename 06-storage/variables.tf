variable "avdLocation" {
  type        = string
  description = "Azure region."
}

variable "tenant_id" {
  type        = string
  description = "Azure tenant ID."
}

variable "prefix" {
  type        = string
  description = "Compatibility variable for shared environment tfvars."
  default     = null
}

variable "environment" {
  type        = string
  description = "Environment name."
  default     = null
}

variable "spoke_subscription_id" {
  type        = string
  description = "Spoke subscription ID."
}

variable "hub_subscription_id" {
  type        = string
  description = "Hub subscription ID."
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to supported resources."
  default     = {}
}

variable "enable_telemetry" {
  type        = bool
  description = "Compatibility variable for shared environment tfvars."
  default     = true
}

variable "rg_storage_name" {
  type        = string
  description = "Resource group that contains the storage accounts."
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
  description = "Private endpoint subnet name."
}

variable "hub_dns_zone_rg" {
  type        = string
  description = "Hub resource group for private DNS zones."
}

variable "active_directory_domain_name" {
  type        = string
  default     = null
  nullable    = true
  description = "Optional AD DS DNS domain name for Azure Files identity authentication."
}

variable "active_directory_domain_guid" {
  type        = string
  default     = null
  nullable    = true
  description = "Optional AD DS domain object GUID for Azure Files identity authentication."

  validation {
    condition = (
      (var.active_directory_domain_name == null && var.active_directory_domain_guid == null) ||
      (var.active_directory_domain_name != null && var.active_directory_domain_guid != null)
    )
    error_message = "Set both active_directory_domain_name and active_directory_domain_guid, or leave both null."
  }
}

variable "fslogix_storage_account_name" {
  type        = string
  description = "Name of the Premium Azure Files storage account for FSLogix profiles."
}

variable "fslogix_managed_identity_name" {
  type        = string
  description = "Managed identity name for the FSLogix storage account."
}

variable "fslogix_file_private_endpoint_name" {
  type        = string
  description = "Private endpoint name for the FSLogix file endpoint."
}

variable "fslogix_file_private_service_connection_name" {
  type        = string
  description = "Private service connection name for the FSLogix file endpoint."
}

variable "fslogix_file_private_dns_zone_group_name" {
  type        = string
  description = "Private DNS zone group name for the FSLogix file endpoint."
}

variable "fslogix_share_name" {
  type        = string
  description = "FSLogix file share name."
  default     = "fslogix"
}

variable "fslogix_share_quota_gb" {
  type        = number
  description = "FSLogix file share quota in GiB."
  default     = 100
}

variable "fslogix_users_group" {
  type        = string
  description = "Display name of the group granted SMB Contributor on the FSLogix share."
}

variable "fslogix_identity_auth_directory_service" {
  type        = string
  description = "Azure Files identity authentication mode. Use AADKERB for Microsoft Entra Kerberos, or null to omit identity authentication."
  default     = "AADKERB"
  nullable    = true
}

variable "general_storage_account_name" {
  type        = string
  description = "Name of the general-purpose storage account."
}

variable "general_managed_identity_name" {
  type        = string
  description = "Managed identity name for the general-purpose storage account."
}

variable "general_blob_private_endpoint_name" {
  type        = string
  description = "Private endpoint name for the general-purpose blob endpoint."
}

variable "general_blob_private_service_connection_name" {
  type        = string
  description = "Private service connection name for the general-purpose blob endpoint."
}

variable "general_blob_private_dns_zone_group_name" {
  type        = string
  description = "Private DNS zone group name for the general-purpose blob endpoint."
}
