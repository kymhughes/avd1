rg_so                                  = "rg-service-objects-npd"
rg_pool                                = "rg-it01-pool-npd"
user_group_name                        = "avd_users_cloud"
hostpool_start_vm_on_connect           = true
hostpool_validate_environment          = true
hostpool_custom_rdp_properties         = "audiocapturemode:i:1;audiomode:i:0;redirectclipboard:i:1;redirectprinters:i:1;drivestoredirect:s:*;"
avd_service_principal_object_id        = "66080947-954d-4adb-933c-293d3bbb3441" # this is the object iD for "Azure Virtual Desktop"
key_vault_name                         = "kv-avd-itm-npd"
workspace_name                         = "workspace-npd"
rg_network                             = "rg-itm-network-npd"
vnet_name                              = "vnet-itm-vnet-npd"
workspace_private_endpoint_subnet_name = "snet-general-pe"
hostpool_private_endpoint_subnet_name  = "snet-general-pe"

host_pools = [
  {
    name                                   = "pool-itm001"
    resource_group_name                    = "rg-pool-itm001-npd"
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

      #     publisher    = "MicrosoftWindowsDesktop"   # Windows 11 AVD image retained for reference.
      #     offer        = "windows-11"
      #     sku          = "win11-25h2-avd"
      #     exactVersion = "26200.9168.260809"

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
        #azureActiveDirectoryInfo = {       #Not applicable for server 2022
        #  mdmProviderGuid = "0000000a-0000-0000-c000-000000000000"
        #}
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
