variable "avdLocation" {
  type        = string
  description = "Azure region for AVD host pool resources."
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
  description = "Fallback host pool compute resource group name."
}

variable "user_group_name" {
  type        = string
  description = "AVD users security group display name."
}

variable "hostpool_name" {
  type        = string
  description = "AVD host pool name."
  default     = null
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

variable "create_registration_token" {
  type        = bool
  description = "Create a host pool registration token for session host deployment."
  default     = true
}

variable "registration_token_ttl" {
  type        = string
  description = "TTL for the generated registration token."
  default     = "24h"
}

variable "app_group_name" {
  type        = string
  description = "Desktop application group name."
  default     = null
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
  description = "AVD workspace name to associate all application groups with."
}

variable "workspace_resource_group_name" {
  type        = string
  description = "Resource group containing the AVD workspace. Defaults to rg_so."
  default     = null
}

variable "avd_users_principal_id" {
  type        = string
  description = "Principal ID granted Desktop Virtualization User on each application group."
  default     = "60de146c-3d1a-46b6-839a-fd84d669b465"
}

variable "scaling_plan_sp_id" {
  type        = string
  description = "Object ID of the AVD service principal used for scaling plan power operations."
}

variable "host_pools" {
  description = "Host pools and matching desktop application groups to create."
  type = list(object({
    name                                   = string
    resource_group_name                    = optional(string)
    avd_users_principal_id                 = optional(string)
    app_group_name                         = string
    app_group_default_desktop_display_name = optional(string)
    app_group_type                         = optional(string)
    hostpool_type                          = optional(string)
    hostpool_load_balancer_type            = optional(string)
    hostpool_maximum_sessions_allowed      = optional(number)
    hostpool_start_vm_on_connect           = optional(bool)
    hostpool_validate_environment          = optional(bool)
    hostpool_custom_rdp_properties         = optional(string)
    create_registration_token              = optional(bool)
    registration_token_ttl                 = optional(string)
    scaling_plan_name                      = optional(string)
    scaling_plan_friendly_name             = optional(string)
    scaling_plan_description               = optional(string)
  }))
  default = []
}

variable "enable_dynamic_scaling_plan" {
  type        = bool
  description = "Create an AVD dynamic autoscale scaling plan."
  default     = true
}

variable "scaling_plan_name" {
  type        = string
  description = "AVD dynamic scaling plan name."
  default     = null
}

variable "scaling_plan_friendly_name" {
  type        = string
  description = "Friendly display name for the AVD dynamic scaling plan."
  default     = null
}

variable "scaling_plan_description" {
  type        = string
  description = "Description for the AVD dynamic scaling plan."
  default     = "Dynamic autoscale scaling plan for Azure Virtual Desktop."
}

variable "scaling_plan_time_zone" {
  type        = string
  description = "Time zone used by the AVD dynamic scaling plan."
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
