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
    vm_template                            = <<EOT
{
  "domain": "",
  "galleryImageOffer": "windows-11",
  "galleryImagePublisher": "MicrosoftWindowsDesktop",
  "galleryImageSKU": "win11-24h2-avd",
  "imageType": "Gallery",
  "customImageId": null,
  "namePrefix": "itm001",
  "osDiskType": "Premium_LRS",
  "vmSize": {
    "id": "Standard_D2s_v5"
  },
  "galleryItemId": "MicrosoftWindowsDesktop.windows-11win11-24h2-avd",
  "hibernate": false,
  "diskSizeGB": 128,
  "securityType": "TrustedLaunch",
  "secureBoot": true,
  "vTPM": true,
  "subnetId": "/subscriptions/e4ea360b-bf76-47bc-bb09-81bd23faad9e/resourceGroups/rg-itm-network-npd/providers/Microsoft.Network/virtualNetworks/vnet-itm-vnet-npd/subnets/snet-itm-001",
  "vmInfrastructureType": "Cloud"
}
EOT
  }
]

enable_dynamic_scaling_plan = true
scaling_plan_time_zone      = "AUS Eastern Standard Time"
scaling_plan_exclusion_tag  = "excludeFromScaling"

dynamic_scaling_plan_schedules = [
  {
    name       = "Weekdays"
    daysOfWeek = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]

    scalingMethod = "CreateDeletePowerManage"

    createDelete = {
      rampUpMinimumHostPoolSize   = 1 #	Don’t pre-create hosts before demand.
      rampUpMaximumHostPoolSize   = 2 # Never scale above 2 hosts during ramp-up.
      rampDownMinimumHostPoolSize = 0 # Allow scale-down to zero.
      rampDownMaximumHostPoolSize = 2 # Keep the max at 2 during ramp-down too.
    }

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

    rampUpMinimumHostsPct        = 00 # Don’t keep any hosts on just for baseline.
    rampUpCapacityThresholdPct   = 90 # Only scale up when existing capacity is nearly full.
    rampDownMinimumHostsPct      = 0
    rampDownCapacityThresholdPct = 90

    rampDownForceLogoffUsers    = false
    rampDownWaitTimeMinutes     = 45
    rampDownNotificationMessage = "Please save your work. Your session may be disconnected soon."
    rampDownStopHostsWhen       = "ZeroActiveSessions"
  }
]
