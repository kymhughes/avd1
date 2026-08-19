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

variable "enable_telemetry" {
  type        = bool
  description = "Enable telemetry for AVM modules."
  default     = true
}

variable "rg_so" {
  type        = string
  description = "Service objects resource group name."
}

variable "rg_pool" {
  type        = string
  description = "Host pool compute resource group name."
}

variable "user_group_name" {
  type        = string
  description = "AVD users security group display name."
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
}

variable "app_group_type" {
  type        = string
  description = "Application group type."
  default     = "RemoteApp"
}

variable "app_group_default_desktop_display_name" {
  type        = string
  description = "Default desktop display name for the Desktop application group."
  default     = "Session Desktop"
}

variable "scaling_plan_sp_id" {
  type        = string
  description = "Object ID of the AVD service principal used for scaling plan power operations."
}
