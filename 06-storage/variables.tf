variable "avdLocation" {
  type        = string
  description = "Azure region"
}

variable "tenant_id" {
  type        = string
  description = "Azure tenant ID."
  default     = null

  validation {
    condition     = !var.manage_private_link_identifier_uris || var.tenant_id != null
    error_message = "tenant_id is required when manage_private_link_identifier_uris is true."
  }
}

variable "prefix" {
  type        = string
  description = "Compatibility variable for shared environment tfvars."
  default     = null
}

variable "environment" {
  type        = string
  description = "Compatibility variable for shared environment tfvars."
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
  description = "Compatibility variable for shared environment tfvars."
  default     = true
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

variable "active_directory_domain_name" {
  type        = string
  default     = null
  nullable    = true
  description = "Optional AD DS DNS domain name applied to all storage accounts for hybrid Microsoft Entra Kerberos ACL management."
}

variable "active_directory_domain_guid" {
  type        = string
  default     = null
  nullable    = true
  description = "Optional AD DS domain object GUID applied to all storage accounts for hybrid Microsoft Entra Kerberos ACL management."

  validation {
    condition = (
      (var.active_directory_domain_name == null && var.active_directory_domain_guid == null) ||
      (var.active_directory_domain_name != null && var.active_directory_domain_guid != null)
    )
    error_message = "Set both active_directory_domain_name and active_directory_domain_guid, or leave both null."
  }
}

variable "manage_private_link_identifier_uris" {
  type        = bool
  default     = false
  description = "Add private-link Azure Files Kerberos identifier URIs to each storage account Entra application. Requires Microsoft Graph application read/write permissions."
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
      name     = string
      quota_gb = number
      smb_role_assignments = optional(map(object({
        group_name           = string
        role_definition_name = optional(string, "Storage File Data SMB Share Contributor")
      })), {})
      smb_admin_groups = optional(list(string), [])
    }))
  }))

  validation {
    condition = alltrue(flatten([
      for storage in values(var.storage_accounts) : [
        for share in values(storage.shares) : [
          for assignment in values(share.smb_role_assignments) : contains([
            "Storage File Data SMB Share Reader",
            "Storage File Data SMB Share Contributor",
            "Storage File Data SMB Share Elevated Contributor"
          ], assignment.role_definition_name)
        ]
      ]
    ]))
    error_message = "Each smb_role_assignments role_definition_name must be SMB Share Reader, Contributor, or Elevated Contributor."
  }
}
