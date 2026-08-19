variable "avdLocation" {
  type        = string
  description = "Azure region for network resources."
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
