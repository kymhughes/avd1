rg_so                                          = "rg-service-objects-npd"
rg_pool                                        = "rg-pool-itm001-npd"
hostpool_name                                  = "pool-itm001"
hostpool_start_vm_on_connect                   = true
hostpool_validate_environment                  = true
hostpool_custom_rdp_properties                 = "audiocapturemode:i:1;audiomode:i:0;redirectclipboard:i:1;redirectprinters:i:1;drivestoredirect:s:*;"
key_vault_name                                 = "kv-avd-itm-npd"
workspace_name                                 = "workspace-npd"
rg_network                                     = "rg-itm-network-npd"
vnet_name                                      = "vnet-itm-vnet-npd"
workspace_private_endpoint_subnet_name         = "snet-general-pe"
hostpool_private_endpoint_subnet_name          = "snet-general-pe"
workspace_feed_private_endpoint_name           = "pe-avd-ws-feed-npd"
workspace_feed_private_service_connection_name = "psc-avd-ws-feed-npd"
workspace_feed_private_dns_zone_group_name     = "dns-avd-ws-feed-npd"
hostpool_private_endpoint_name                 = "pe-avd-hp-pool-itm001"
hostpool_private_service_connection_name       = "psc-avd-hp-pool-itm001"
hostpool_private_dns_zone_group_name           = "dns-avd-hp-pool-itm001"

avd_users_group                        = "avd_users_cloud"
app_group_name                         = "app-itm001"
app_group_default_desktop_display_name = "itm001"
scaling_plan_name                      = "sp-itm001-npd"
scaling_plan_friendly_name             = "ITM001 NPD Dynamic Autoscale"
scaling_plan_description               = "Default dynamic autoscale plan for ITM001 NPD."
session_host_subnet_name               = "snet-itm-001"

session_host_configuration = {
  friendlyName = "ITM001 NPD session hosts"
  vmLocation   = "australiaeast"
  vmNamePrefix = "itm001"
  vmSizeId     = "Standard_D2s_v5"

  # Windows 11 AVD image retained for reference.
  # imageInfo = {
  #   type = "Marketplace"
  #   marketplaceInfo = {
  #     publisher    = "MicrosoftWindowsDesktop"
  #     offer        = "windows-11"
  #     sku          = "win11-25h2-avd"
  #     exactVersion = "26200.9168.260809"
  #   }
  # }

  imageInfo = {
    type = "Marketplace"
    marketplaceInfo = {
      publisher    = "MicrosoftWindowsServer"
      offer        = "WindowsServer"
      sku          = "2022-datacenter-azure-edition"
      exactVersion = "20348.5499.260809"
    }
  }

  diskInfo = {
    managedDisk = {
      type = "Premium_LRS"
    }
  }

  domainInfo = {
    joinType                 = "AzureActiveDirectory"
    azureActiveDirectoryInfo = {}
  }

  securityInfo = {
    type              = "TrustedLaunch"
    secureBootEnabled = true
    vTpmEnabled       = true
  }

  bootDiagnosticsInfo = {
    enabled = true
  }

  vmAdminCredentials = {
    usernameKeyVaultSecretUri = "https://kv-avd-itm-npd.vault.azure.net/secrets/vm-local-admin-username"
    passwordKeyVaultSecretUri = "https://kv-avd-itm-npd.vault.azure.net/secrets/local-password"
  }

  vmTags = {
    environment = "npd"
    workload    = "avd"
    managedBy   = "terraform"
  }
}

enable_dynamic_scaling_plan = true
scaling_plan_time_zone      = "AUS Eastern Standard Time"
scaling_plan_exclusion_tag  = "excludeFromScaling"

dynamic_scaling_plan_schedules = [
  {
    name       = "Weekdays"
    daysOfWeek = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]

    scalingMethod = "CreateDeletePowerManage"

    createDelete = {
      rampUpMinimumHostPoolSize   = 1
      rampUpMaximumHostPoolSize   = 2
      rampDownMinimumHostPoolSize = 0
      rampDownMaximumHostPoolSize = 2
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

    rampUpMinimumHostsPct        = 0
    rampUpCapacityThresholdPct   = 90
    rampDownMinimumHostsPct      = 0
    rampDownCapacityThresholdPct = 90

    rampDownForceLogoffUsers    = false
    rampDownWaitTimeMinutes     = 45
    rampDownNotificationMessage = "Please save your work. Your session may be disconnected soon."
    rampDownStopHostsWhen       = "ZeroActiveSessions"
  }
]
