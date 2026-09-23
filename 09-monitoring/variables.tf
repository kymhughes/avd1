variable "avdLocation" {
  type        = string
  description = "Azure region."
}

variable "environment" {
  type        = string
  description = "Environment name, for example npd, uat, or prd."
}

variable "spoke_subscription_id" {
  type        = string
  description = "Spoke subscription ID."
}

variable "rg_monitoring_name" {
  type        = string
  description = "Monitoring resource group name to create."
}

variable "log_analytics_workspace_name" {
  type        = string
  description = "Log Analytics workspace name."
}

variable "enable_telemetry" {
  type        = bool
  default     = true
  description = "Enable AVM telemetry"
}

variable "enable_diagnostic_policies" {
  type        = bool
  default     = true
  description = "Enable subscription policy assignments that deploy diagnostic settings to supported AVD platform resources."
}

variable "diagnostic_setting_name" {
  type        = string
  default     = "setByPolicy-logAnalytics"
  description = "Diagnostic setting name created by Azure Policy remediation."
}

variable "enable_diagnostic_policy_remediation" {
  type        = bool
  default     = true
  description = "Create remediation tasks for the diagnostic policy assignments so existing resources are evaluated."
}

variable "diagnostic_policy_resource_types" {
  description = "Resource types that should receive diagnostic settings through subscription policy."
  type = map(object({
    display_name   = string
    resource_type  = string
    enable_logs    = optional(bool, true)
    enable_metrics = optional(bool, true)
  }))
  default = {
    storage_accounts = {
      display_name = "Storage accounts"
      # The storage account resource supports platform metrics; service-level logs
      # are exposed on child services such as blobServices and fileServices.
      resource_type = "Microsoft.Storage/storageAccounts"
      enable_logs   = false
    }
    key_vaults = {
      display_name  = "Key Vaults"
      resource_type = "Microsoft.KeyVault/vaults"
    }
    avd_workspaces = {
      display_name   = "AVD workspaces"
      resource_type  = "Microsoft.DesktopVirtualization/workspaces"
      enable_metrics = false
    }
    avd_app_groups = {
      display_name   = "AVD application groups"
      resource_type  = "Microsoft.DesktopVirtualization/applicationGroups"
      enable_metrics = false
    }
    avd_host_pools = {
      display_name   = "AVD host pools"
      resource_type  = "Microsoft.DesktopVirtualization/hostPools"
      enable_metrics = false
    }
    session_host_vms = {
      display_name = "Session host virtual machines"
      # AVD session hosts are Azure VMs; VM diagnostic settings expose platform metrics.
      resource_type  = "Microsoft.Compute/virtualMachines"
      enable_logs    = false
      enable_metrics = true
    }
  }
}

variable "tags" {
  type        = map(string)
  description = "Shared environment tags."
  default     = {}
}

variable "tenant_id" {
  type        = string
  description = "Compatibility variable supplied by shared environment tfvars."
  default     = null
}

variable "hub_subscription_id" {
  type        = string
  description = "Compatibility variable supplied by shared environment tfvars."
  default     = null
}

variable "hub_dns_zone_rg" {
  type        = string
  description = "Compatibility variable supplied by shared environment tfvars."
  default     = null
}

variable "rg_network" {
  type        = string
  description = "Compatibility variable supplied by shared environment tfvars."
  default     = null
}

variable "vnet_name" {
  type        = string
  description = "Compatibility variable supplied by shared environment tfvars."
  default     = null
}

variable "rg_so" {
  type        = string
  description = "Compatibility variable supplied by shared environment tfvars."
  default     = null
}

variable "workspace_name" {
  type        = string
  description = "Compatibility variable supplied by shared environment tfvars."
  default     = null
}

variable "rg_storage_name" {
  type        = string
  description = "Compatibility variable supplied by shared environment tfvars."
  default     = null
}

variable "pesubnet_workspace" {
  type        = string
  description = "Compatibility variable supplied by shared environment tfvars."
  default     = null
}

variable "pesubnet_keyvault" {
  type        = string
  description = "Compatibility variable supplied by shared environment tfvars."
  default     = null
}

variable "pesubnet_files" {
  type        = string
  description = "Compatibility variable supplied by shared environment tfvars."
  default     = null
}

variable "avd_service_principal_object_id" {
  type        = string
  description = "Compatibility variable supplied by shared environment tfvars."
  default     = null
}
