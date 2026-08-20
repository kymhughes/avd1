variable "avdLocation" {
  type        = string
  description = "Azure region for network resources."
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

variable "subnets" {
  description = "Subnets to create, with optional NSG creation and security rules."
  type = map(object({
    address_prefixes  = list(string)
    name              = optional(string)
    service_endpoints = optional(list(string), [])

    delegations = optional(map(object({
      service_name = string
      actions      = optional(list(string), [])
    })), {})

    private_subnet_enabled                        = optional(bool, false)
    private_endpoint_network_policies             = optional(string, "Disabled")
    private_link_service_network_policies_enabled = optional(bool, true)

    nsg = optional(object({
      create                             = optional(bool, false)
      existing_network_security_group_id = optional(string)

      security_rules = optional(map(object({
        priority  = number
        direction = optional(string, "Inbound")
        access    = optional(string, "Allow")
        protocol  = optional(string, "*")

        description = optional(string)

        source_port_range       = optional(string)
        source_port_ranges      = optional(list(string))
        destination_port_range  = optional(string)
        destination_port_ranges = optional(list(string))

        source_address_prefix        = optional(string)
        source_address_prefixes      = optional(list(string))
        destination_address_prefix   = optional(string)
        destination_address_prefixes = optional(list(string))
      })), {})
    }))
  }))

  validation {
    condition = alltrue([
      for _, subnet in var.subnets : contains(
        ["Disabled", "Enabled", "NetworkSecurityGroupEnabled", "RouteTableEnabled"],
        subnet.private_endpoint_network_policies
      )
    ])
    error_message = "private_endpoint_network_policies must be one of Disabled, Enabled, NetworkSecurityGroupEnabled, or RouteTableEnabled."
  }

  validation {
    condition = alltrue([
      for _, subnet in var.subnets :
      !(try(subnet.nsg.create, false) && try(subnet.nsg.existing_network_security_group_id, null) != null)
    ])
    error_message = "A subnet NSG can either be created or associated from existing_network_security_group_id, not both."
  }

  validation {
    condition = alltrue([
      for _, subnet in var.subnets :
      try(length(subnet.nsg.security_rules) == 0 || subnet.nsg.create, true)
    ])
    error_message = "security_rules can only be set when the subnet NSG create option is true."
  }
}
