variable "avdLocation" {
  type        = string
  description = "Azure region for AVD host pool resources."
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

variable "hub_dns_zone_rg" {
  type        = string
  description = "Hub resource group containing private DNS zones."
  default     = null
}

variable "rg_so" {
  type        = string
  description = "Service objects resource group name."
}

variable "rg_pool" {
  type        = string
  description = "Host pool resource group name."
}

variable "hostpool_name" {
  type        = string
  description = "AVD host pool name."
}

variable "hostpool_type" {
  type        = string
  description = "Host pool type."
  default     = "Pooled"
}

variable "hostpool_load_balancer_type" {
  type        = string
  description = "Host pool load balancer type."
  default     = "DepthFirst"
}

variable "hostpool_maximum_sessions_allowed" {
  type        = number
  description = "Maximum sessions allowed per session host."
  default     = 2
}

variable "hostpool_start_vm_on_connect" {
  type        = bool
  description = "Start session hosts on user connection."
  default     = false
}

variable "hostpool_validate_environment" {
  type        = bool
  description = "Enable host pool validation environment."
  default     = false
}

variable "hostpool_custom_rdp_properties" {
  type        = string
  description = "Custom RDP properties for the AVD host pool."
  default     = "audiocapturemode:i:1;audiomode:i:0;redirectclipboard:i:1;redirectprinters:i:1;drivestoredirect:s:*;"
}

variable "app_group_name" {
  type        = string
  description = "Desktop application group name."
}

variable "app_group_type" {
  type        = string
  description = "Application group type."
  default     = "Desktop"
}

variable "app_group_default_desktop_display_name" {
  type        = string
  description = "Default desktop display name for the Desktop application group."
  default     = "Session Desktop"
}

variable "workspace_name" {
  type        = string
  description = "AVD workspace name to associate the application group with."
}

variable "workspace_resource_group_name" {
  type        = string
  description = "Resource group containing the AVD workspace. Defaults to rg_so."
  default     = null
}

variable "avd_users_group" {
  type        = string
  description = "Display name of the group granted Desktop Virtualization User and VM User Login."
  default     = "avd_users_cloud"
}

variable "key_vault_name" {
  type        = string
  description = "Name of the Key Vault containing session host admin secrets."
}

variable "rg_network" {
  type        = string
  description = "Resource group containing the spoke virtual network."
}

variable "vnet_name" {
  type        = string
  description = "Spoke virtual network name."
}

variable "session_host_subnet_name" {
  type        = string
  description = "Subnet name for session hosts."
}

variable "session_host_configuration" {
  type        = any
  description = "Session host configuration properties. networkInfo.subnetId is generated from rg_network, vnet_name, and session_host_subnet_name."
}

variable "scheduled_agent_updates" {
  description = "Optional scheduled AVD agent update configuration."
  type = object({
    enabled                   = optional(bool, true)
    timezone                  = optional(string, "AUS Eastern Standard Time")
    use_session_host_timezone = optional(bool, false)
    schedules = list(object({
      day_of_week = string
      hour_of_day = number
    }))
  })
  default = {
    enabled                   = true
    timezone                  = "AUS Eastern Standard Time"
    use_session_host_timezone = false
    schedules = [
      {
        day_of_week = "Saturday"
        hour_of_day = 2
      }
    ]
  }
}

variable "enable_private_endpoints" {
  type        = bool
  description = "Create private endpoints for the AVD workspace feed and host pool connection."
  default     = true
}

variable "workspace_private_endpoint_subnet_name" {
  type        = string
  description = "Subnet name for the AVD workspace feed private endpoint."
}

variable "hostpool_private_endpoint_subnet_name" {
  type        = string
  description = "Subnet name for the AVD host pool connection private endpoint."
}

variable "workspace_feed_private_endpoint_name" {
  type        = string
  description = "Workspace feed private endpoint name."
}

variable "workspace_feed_private_service_connection_name" {
  type        = string
  description = "Workspace feed private service connection name."
}

variable "workspace_feed_private_dns_zone_group_name" {
  type        = string
  description = "Workspace feed private DNS zone group name."
}

variable "hostpool_private_endpoint_name" {
  type        = string
  description = "Host pool connection private endpoint name."
}

variable "hostpool_private_service_connection_name" {
  type        = string
  description = "Host pool connection private service connection name."
}

variable "hostpool_private_dns_zone_group_name" {
  type        = string
  description = "Host pool connection private DNS zone group name."
}

variable "enable_dynamic_scaling_plan" {
  type        = bool
  description = "Create an AVD dynamic autoscale scaling plan."
  default     = true
}

variable "scaling_plan_name" {
  type        = string
  description = "AVD scaling plan name."
}

variable "scaling_plan_friendly_name" {
  type        = string
  description = "Friendly display name for the AVD scaling plan."
}

variable "scaling_plan_description" {
  type        = string
  description = "Description for the AVD dynamic scaling plan."
  default     = "Dynamic autoscale scaling plan for Azure Virtual Desktop."
}

variable "scaling_plan_time_zone" {
  type        = string
  description = "Time zone used by the AVD scaling plan."
  default     = "AUS Eastern Standard Time"
}

variable "scaling_plan_exclusion_tag" {
  type        = string
  description = "Optional tag name used to exclude session hosts from autoscale."
  default     = null
}

variable "dynamic_scaling_plan_schedules" {
  description = "Default dynamic autoscale schedules. Created by Terraform, then ignored so operators can tune schedules later."
  type = list(object({
    name       = string
    daysOfWeek = list(string)

    scalingMethod = string

    createDelete = object({
      rampUpMinimumHostPoolSize   = number
      rampUpMaximumHostPoolSize   = number
      rampDownMinimumHostPoolSize = number
      rampDownMaximumHostPoolSize = number
    })

    rampUpStartTime = object({
      hour   = number
      minute = number
    })
    peakStartTime = object({
      hour   = number
      minute = number
    })
    rampDownStartTime = object({
      hour   = number
      minute = number
    })
    offPeakStartTime = object({
      hour   = number
      minute = number
    })

    rampUpLoadBalancingAlgorithm   = string
    peakLoadBalancingAlgorithm     = string
    rampDownLoadBalancingAlgorithm = string
    offPeakLoadBalancingAlgorithm  = string
    rampUpMinimumHostsPct          = number
    rampUpCapacityThresholdPct     = number
    rampDownMinimumHostsPct        = number
    rampDownCapacityThresholdPct   = number
    rampDownForceLogoffUsers       = bool
    rampDownWaitTimeMinutes        = number
    rampDownNotificationMessage    = string
    rampDownStopHostsWhen          = string
  }))
  default = []
}
