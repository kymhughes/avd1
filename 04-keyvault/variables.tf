variable "avdLocation" {
  type        = string
  description = "Azure region for Key Vault."
}

variable "tenant_id" {
  type        = string
  description = "Azure tenant ID."
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
