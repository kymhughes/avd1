variable "avdLocation" {
  type        = string
  description = "Azure region for network resources."
}

variable "tenant_id" {
  type        = string
  description = "Azure tenant ID."
  default     = null
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

variable "hub_dns_zone_rg" {
  type        = string
  description = "Hub resource group containing private DNS zones."
  default     = null
}

variable "rg_network" {
  type        = string
  description = "Network resource group name."
}

variable "vnet_name" {
  type        = string
  description = "Spoke virtual network name."
}

variable "vnet_range" {
  type        = list(string)
  description = "Spoke virtual network address space."
}

variable "dns_servers" {
  type        = list(string)
  description = "DNS servers for the spoke virtual network."
}

variable "hub_connectivity_rg" {
  type        = string
  description = "Hub virtual network resource group name."
}

variable "hub_vnet" {
  type        = string
  description = "Hub virtual network name."
}
