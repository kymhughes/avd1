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
