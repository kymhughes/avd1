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

variable "pesubnet_id" {
  type        = string
  description = "Private endpoint subnet ID (from module 02: pesubnet_id)"
}

variable "spoke_vnet_id" {
  type        = string
  description = "Spoke VNet ID (from module 02: vnet_id)"
}

variable "hub_dns_zone_rg" {
  type        = string
  description = "Hub resource group for private DNS zones"
}

variable "fslogix_share_quota_gb" {
  type        = number
  default     = 100
  description = "FSLogix file share quota in GB"
}
