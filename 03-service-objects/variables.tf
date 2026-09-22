variable "avdLocation" {
  type        = string
  description = "Azure region for service objects."
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

variable "rg_so" {
  type        = string
  description = "Service objects resource group name."
}

variable "user_group_name" {
  type        = string
  description = "AVD users security group display name."
}

variable "workspace_name" {
  type        = string
  description = "AVD workspace name."
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

variable "pesubnet_workspace" {
  type        = string
  description = "Workspace private endpoint subnet name."
}

variable "workspace_pe_name" {
  type        = string
  description = "Workspace private endpoint name."
}
variable "workspace_sc_name" {
  type        = string
  description = "Workspace service connection name."
}

variable "workspace_dns_zone_group_name" {
  type        = string
  description = "Workspace private endpoint DNS zone group name."
}

variable "avd_service_principal_object_id" {
  type        = string
  description = "Object ID of the Azure Virtual Desktop service principal used for dynamic autoscale."
}
