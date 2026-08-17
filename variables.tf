variable "avdLocation" {
  type        = string
  description = "Azure region for all resources (e.g. australiaeast)"
}

variable "tenant_id" {
  type        = string
  description = "Azure tenant ID"
}

variable "tags" {
  description = "Tags applied to supported resources."
  type        = map(string)
  default     = {}
}

variable "prefix" {
  type        = string
  description = "Short prefix for resource naming — lowercase, max 4 chars"
}

variable "environment" {
  type        = string
  description = "Environment name: dev | test | prod"
}

variable "spoke_subscription_id" {
  type        = string
  description = "Azure subscription ID for the AVD spoke workload"
}

variable "hub_subscription_id" {
  type        = string
  description = "Azure subscription ID for the hub virtual network"
}

variable "rg_network" {
  type        = string
  description = "Suffix for the Network resource group"
}

variable "rg_so" {
  type        = string
  description = "Suffix for the Service Objects resource group"
}

variable "rg_stor" {
  type        = string
  description = "Suffix for the Storage resource group"
}

variable "rg_pool" {
  type        = string
  description = "Suffix for the Compute Pool resource group"
}

variable "user_group_name" {
  type        = string
  description = "Name of the AVD user group"
}

variable "vnet_name" {
  type        = string
  description = "Name of the virtual network"
}

variable "vnet_range" {
  type        = list(string)
  description = "Address space for the virtual network"
}

variable "dns_servers" {
  type        = list(string)
  description = "DNS servers for the virtual network"
}

variable "hub_connectivity_rg" {
  type        = string
  description = "Resource group name of the hub virtual network"
}

variable "hub_vnet" {
  type        = string
  description = "Name of the hub virtual network"
}

variable "keyvault_name" {
  type        = string
  description = "Name of the Key Vault for AVD secrets"
}

variable "enable_telemetry" {
  type    = bool
  default = true
}

variable "hostpool_name" {
  type        = string
  default     = "vdpool"
  description = "Host pool name prefix"
}

variable "hostpool_type" {
  type        = string
  default     = "Pooled"
  description = "Host pool type: Pooled | Personal"
}

variable "hostpool_load_balancer_type" {
  type        = string
  default     = "DepthFirst"
  description = "Host pool load balancer type: DepthFirst | BreadthFirst"
}

variable "hostpool_maximum_sessions_allowed" {
  type        = number
  default     = 2
  description = "Maximum sessions allowed per session host in the host pool"
}

variable "hostpool_start_vm_on_connect" {
  type    = bool
  default = false
}

variable "hostpool_validate_environment" {
  type    = bool
  default = false
}

variable "hostpool_custom_rdp_properties" {
  type        = string
  description = "Custom RDP properties for the AVD host pool."
  default     = "audiocapturemode:i:1;audiomode:i:0;redirectclipboard:i:1;redirectprinters:i:1;drivestoredirect:s:*;"
}

variable "workspace_name" {
  type        = string
  default     = "workspace1"
  description = "Workspace name prefix"
}

variable "app_group_name" {
  type        = string
  default     = "vdag"
  description = "Desktop Application Group name prefix"
}

variable "app_group_type" {
  type        = string
  default     = "RemoteApp"
  description = "Application Group type: Desktop | RemoteApp"
}

variable "app_group_default_desktop_display_name" {
  type        = string
  default     = "Session Desktop"
  description = "Default desktop display name for the Desktop Application Group"
}


variable "scplan_name" {
  type        = string
  default     = "vdscaling"
  description = "Scaling plan name prefix"
}

variable "scaling_plan_sp_id" {
  type        = string
  description = "Object ID of the 'Azure Virtual Desktop' service principal — needed for scaling plan power operations on the host pool. Get via: az ad sp list --display-name 'Windows Virtual Desktop' --query '[].id' -o tsv"
}

variable "host_pool_log_categories" {
  type    = list(string)
  default = ["Checkpoint", "Error", "Management", "Connection", "HostRegistration", "AgentHealthStatus", "NetworkData", "SessionHostManagement", "ConnectionGraphicsData"]
}

variable "dag_log_categories" {
  type    = list(string)
  default = ["Checkpoint", "Error", "Management"]
}

variable "ws_log_categories" {
  type    = list(string)
  default = ["Checkpoint", "Error", "Management", "Feed"]
}

variable "hub_dns_zone_rg" {
  type        = string
  description = "Resource group name of the hub private DNS zone for AVD workspace feed"
}

variable "pesubnet_id" {
  type        = string
  description = "Resource ID of the spoke private endpoint subnet for AVD workspace feed"
}

variable "pesubnet_avdglobal" {
  type        = string
  description = "Name of the spoke private endpoint subnet for AVD global service endpoints"
}

variable "pesubnet_workspace" {
  type        = string
  description = "Name of the spoke private endpoint subnet for AVD workspace feed"
}

variable "pesubnet_hostpool1" {
  type        = string
  description = "Name of the spoke private endpoint subnet for AVD host pool 1"
}

variable "pesubnet_keyvault" {
  type        = string
  description = "Name of the spoke private endpoint subnet for Key Vault"
}

variable "subnets" {
  description = <<-EOT
    Subnets to create. Each subnet can optionally create an NSG with rules, associate an existing NSG,
    disable default outbound access as a private subnet, and select private endpoint network policy mode.
  EOT

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


variable "local_password_length" {
  description = "Length of the generated local password."
  type        = number
  default     = 24

  validation {
    condition     = var.local_password_length >= 12
    error_message = "The local password length must be at least 12 characters."
  }
}

variable "local_password_secret_name" {
  description = "Name of the Key Vault secret used to store the generated local password."
  type        = string
  default     = "local-password"

  validation {
    condition     = can(regex("^[0-9A-Za-z-]+$", var.local_password_secret_name))
    error_message = "The local password secret name can contain only letters, numbers, and hyphens."
  }
}

variable "avd_host_pool_id" {
  description = "Resource ID of the AVD host pool to generate a registration token for. Leave null to skip token creation."
  type        = string
  default     = null
}

variable "avd_registration_token_expiry_hours" {
  description = "Number of hours before the generated AVD host pool registration token expires."
  type        = number
  default     = 24

  validation {
    condition     = var.avd_registration_token_expiry_hours >= 1 && var.avd_registration_token_expiry_hours <= 720
    error_message = "The AVD registration token expiry must be between 1 and 720 hours."
  }
}

variable "avd_registration_token_secret_name" {
  description = "Name of the Key Vault secret used to store the generated AVD host pool registration token."
  type        = string
  default     = "avd-registration-token"

  validation {
    condition     = can(regex("^[0-9A-Za-z-]+$", var.avd_registration_token_secret_name))
    error_message = "The AVD registration token secret name can contain only letters, numbers, and hyphens."
  }
}

variable "private_link_secret_wait_duration" {
  description = "Duration to wait after private endpoint and private DNS wiring before writing Key Vault secrets."
  type        = string
  default     = "60s"
}
