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
    display_name      = string
    resource_type     = string
    log_categories    = optional(list(string), [])
    metric_categories = optional(list(string), [])
  }))
  default = {
    storage_accounts = {
      display_name      = "Storage accounts"
      resource_type     = "Microsoft.Storage/storageAccounts"
      metric_categories = ["Capacity", "Transaction"]
    }
    storage_blob_services = {
      display_name      = "Storage blob services"
      resource_type     = "Microsoft.Storage/storageAccounts/blobServices"
      log_categories    = ["StorageRead", "StorageWrite", "StorageDelete"]
      metric_categories = ["Capacity", "Transaction"]
    }
    storage_file_services = {
      display_name      = "Storage file services"
      resource_type     = "Microsoft.Storage/storageAccounts/fileServices"
      log_categories    = ["StorageRead", "StorageWrite", "StorageDelete"]
      metric_categories = ["Capacity", "SLI", "Transaction"]
    }
    key_vaults = {
      display_name      = "Key Vaults"
      resource_type     = "Microsoft.KeyVault/vaults"
      log_categories    = ["AuditEvent", "AzurePolicyEvaluationDetails"]
      metric_categories = ["AllMetrics"]
    }
    avd_workspaces = {
      display_name   = "AVD workspaces"
      resource_type  = "Microsoft.DesktopVirtualization/workspaces"
      log_categories = ["Checkpoint", "Error", "Management", "Feed"]
    }
    avd_app_groups = {
      display_name   = "AVD application groups"
      resource_type  = "Microsoft.DesktopVirtualization/applicationGroups"
      log_categories = ["Checkpoint", "Error", "Management"]
    }
    avd_host_pools = {
      display_name  = "AVD host pools"
      resource_type = "Microsoft.DesktopVirtualization/hostPools"
      log_categories = [
        "Checkpoint",
        "Error",
        "Management",
        "Connection",
        "HostRegistration",
        "AgentHealthStatus",
        "NetworkData",
        "ConnectionGraphicsData",
        "SessionHostManagement",
        "AutoscaleEvaluationPooled",
        "MultiLinkAdd"
      ]
    }
  }
}

variable "data_collection_rule_name" {
  type        = string
  default     = "dcr-avd-session-hosts"
  description = "Data Collection Rule name for AVD session host guest telemetry."
}

variable "data_collection_rule_association_name" {
  type        = string
  default     = "dcra-avd-session-hosts"
  description = "Data Collection Rule association name deployed to session host VMs by Azure Policy."
}

variable "enable_ama_policies" {
  type        = bool
  default     = true
  description = "Enable subscription policy assignments that deploy Azure Monitor Agent and DCR associations to VMs."
}

variable "enable_ama_policy_remediation" {
  type        = bool
  default     = true
  description = "Create remediation tasks for the Azure Monitor Agent and DCR association policies."
}

variable "session_host_vm_tag_name" {
  type        = string
  default     = "workload"
  description = "VM tag name used by Azure Policy to identify AVD session hosts."
}

variable "session_host_vm_tag_like" {
  type        = string
  default     = "avd*"
  description = "Azure Policy like-pattern used against session_host_vm_tag_name to identify AVD session hosts."
}

variable "session_host_perf_counters" {
  type        = list(string)
  description = "Windows performance counters collected from AVD session hosts by AMA."
  default = [
    "\\Processor Information(_Total)\\% Processor Time",
    "\\Memory\\Available MBytes",
    "\\Memory\\% Committed Bytes In Use",
    "\\LogicalDisk(_Total)\\% Free Space",
    "\\LogicalDisk(_Total)\\Avg. Disk sec/Read",
    "\\LogicalDisk(_Total)\\Avg. Disk sec/Write",
    "\\Network Interface(*)\\Bytes Total/sec",
    "\\Terminal Services\\Active Sessions",
    "\\Terminal Services\\Inactive Sessions"
  ]
}

variable "session_host_windows_event_logs" {
  type        = list(string)
  description = "Windows Event Log XPath queries collected from AVD session hosts by AMA."
  default = [
    "Application!*[System[(Level=1 or Level=2 or Level=3)]]",
    "System!*[System[(Level=1 or Level=2 or Level=3)]]",
    "Microsoft-Windows-TerminalServices-LocalSessionManager/Operational!*[System[(Level=1 or Level=2 or Level=3 or Level=4)]]",
    "Microsoft-Windows-TerminalServices-RemoteConnectionManager/Operational!*[System[(Level=1 or Level=2 or Level=3 or Level=4)]]",
    "Microsoft-FSLogix-Apps/Operational!*[System[(Level=1 or Level=2 or Level=3 or Level=4)]]"
  ]
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
