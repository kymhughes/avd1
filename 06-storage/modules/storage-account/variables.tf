variable "storage_key" {
  type        = string
  description = "Key of this storage account in the parent storage_accounts map."
}

variable "storage_account" {
  description = "One storage account and its Azure Files shares."
  type = object({
    name                            = string
    managed_identity_name           = string
    kind                            = string
    sku_name                        = string
    identity_auth_directory_service = optional(string)
    private_endpoint_name           = string
    private_service_connection_name = string
    private_dns_zone_group_name     = string
    private_dns_vnet_link_name      = optional(string)
    shares = map(object({
      name     = string
      quota_gb = number
      smb_role_assignments = optional(map(object({
        group_name           = string
        role_definition_name = optional(string, "Storage File Data SMB Share Contributor")
      })), {})
      smb_admin_groups = optional(list(string), [])
    }))
  })
}

variable "avdLocation" {
  type        = string
  description = "Azure region."
}

variable "spoke_subscription_id" {
  type        = string
  description = "Spoke subscription ID."
}

variable "rg_storage_name" {
  type        = string
  description = "Storage resource group name."
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

variable "private_dns_zone_id" {
  type        = string
  description = "Resource ID of privatelink.file.core.windows.net."
}

variable "active_directory_domain_name" {
  type        = string
  default     = null
  nullable    = true
  description = "Optional AD DS DNS domain name for hybrid Microsoft Entra Kerberos ACL management."
}

variable "active_directory_domain_guid" {
  type        = string
  default     = null
  nullable    = true
  description = "Optional AD DS domain object GUID for hybrid Microsoft Entra Kerberos ACL management."
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags applied to supported resources."
}
