variable "avdLocation" {
  type        = string
  description = "Azure region."
  default     = null
}

variable "tenant_id" {
  type        = string
  description = "Azure AD tenant ID"
}

variable "prefix" {
  type        = string
  description = "Short prefix for resource naming."
  default     = null
}

variable "environment" {
  type        = string
  description = "Environment name."
  default     = null
}

variable "spoke_subscription_id" {
  type        = string
  description = "Spoke subscription ID"
}

variable "hub_subscription_id" {
  type        = string
  description = "Hub subscription ID."
  default     = null
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

variable "hub_dns_zone_rg" {
  type        = string
  description = "Hub resource group containing private DNS zones."
  default     = null
}

variable "user_group_name" {
  type        = string
  description = "Azure AD security group for AVD users"
}

variable "rg_compute_id" {
  type        = string
  description = "Compute resource group ID (from module 01: rg_compute_id)"
}

variable "storage_account_id" {
  type        = string
  default     = null
  nullable    = true
  description = "FSLogix storage account ID (from module 06: storage_account_id). Leave null to skip the SMB role assignment."
}
variable "scaling_plan_service_principal_id" {
  type        = string
  description = "Object ID of the AVD/Windows Virtual Desktop service principal for scaling plan power operations"
}
