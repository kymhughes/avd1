rg_so                          = "rg-service-objects-npd"
rg_pool                        = "rg-it01-pool-npd"
user_group_name                = "avd_users_cloud"
hostpool_start_vm_on_connect   = true
hostpool_validate_environment  = true
hostpool_custom_rdp_properties = "audiocapturemode:i:1;audiomode:i:0;redirectclipboard:i:1;redirectprinters:i:1;drivestoredirect:s:*;"
scaling_plan_sp_id             = "6774ae85-d784-4d45-9585-876477e8f6b7"
workspace_name                 = "workspace-npd"

host_pools = [
  {
    name                                   = "pool-itm001"
    resource_group_name                    = "rg-pool-itm001-npd"
    avd_users_principal_id                 = "60de146c-3d1a-46b6-839a-fd84d669b465"
    app_group_name                         = "app-itm001"
    app_group_default_desktop_display_name = "itm001"
    scaling_plan_name                      = "sp-itm001-npd"
    scaling_plan_friendly_name             = "ITM001 NPD Dynamic Autoscale"
    scaling_plan_description               = "Default dynamic autoscale plan for ITM001 NPD."
  }
]

enable_dynamic_scaling_plan = true
scaling_plan_time_zone      = "AUS Eastern Standard Time"
scaling_plan_exclusion_tag  = "excludeFromScaling"

dynamic_scaling_plan_schedules = [
  {
    name       = "Weekdays"
    daysOfWeek = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]

    scalingMethod = "PowerManage"

    rampUpStartTime = {
      hour   = 7
      minute = 0
    }
    peakStartTime = {
      hour   = 9
      minute = 0
    }
    rampDownStartTime = {
      hour   = 18
      minute = 0
    }
    offPeakStartTime = {
      hour   = 19
      minute = 0
    }

    rampUpLoadBalancingAlgorithm   = "BreadthFirst"
    peakLoadBalancingAlgorithm     = "BreadthFirst"
    rampDownLoadBalancingAlgorithm = "DepthFirst"
    offPeakLoadBalancingAlgorithm  = "DepthFirst"

    rampUpMinimumHostsPct        = 10
    rampUpCapacityThresholdPct   = 60
    rampDownMinimumHostsPct      = 10
    rampDownCapacityThresholdPct = 80

    rampDownForceLogoffUsers    = false
    rampDownWaitTimeMinutes     = 45
    rampDownNotificationMessage = "Please save your work. Your session may be disconnected soon."
    rampDownStopHostsWhen       = "ZeroActiveSessions"
  }
]
