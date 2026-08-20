variable "avdLocation" {
  type        = string
  description = "Azure region for Key Vault."
}

variable "tenant_id" {
  type        = string
  description = "Azure tenant ID."
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
  description = "Azure subscription ID for the AVD spoke workload."
}

variable "hub_subscription_id" {
  type        = string
  description = "Azure subscription ID for the hub virtual network."
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

variable "rg_so" {
  type        = string
  description = "Service objects resource group name."
}

variable "keyvault_name" {
  type        = string
  description = "Key Vault name."
}

variable "vm_local_admin_username" {
  type        = string
  description = "Local administrator username for AVD session hosts."
  default     = "localadmin"
}

variable "vm_local_admin_username_secret_name" {
  type        = string
  description = "Key Vault secret name for the AVD session host local administrator username."
  default     = "vm-local-admin-username"
}

variable "vm_local_admin_password_secret_name" {
  type        = string
  description = "Key Vault secret name for the AVD session host local administrator password."
  default     = "local-password"
}

variable "hub_dns_zone_rg" {
  type        = string
  description = "Hub resource group containing private DNS zones."
}

variable "rg_network" {
  type        = string
  description = "Network resource group name."
}

variable "vnet_name" {
  type        = string
  description = "Spoke virtual network name."
}

variable "pesubnet_keyvault" {
  type        = string
  description = "Key Vault private endpoint subnet name."
}
variable "keyvault_pe_name" {
  type        = string
  description = "Key Vault private endpoint name."
}
variable "keyvault_sc_name" {
  type        = string
  description = "Key Vault service connection name."
}
