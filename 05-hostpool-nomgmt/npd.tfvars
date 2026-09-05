rg_so                          = "rg-service-objects-npd"
hostpool_start_vm_on_connect   = true
hostpool_validate_environment  = true
key_vault_name                 = "kv-avd-itm-npd"
workspace_name                 = "workspace-npd"
rg_network                     = "rg-itm-network-npd"
vnet_name                      = "vnet-itm-vnet-npd"
enable_dynamic_scaling_plan    = true
scaling_plan_time_zone         = "AUS Eastern Standard Time"
scaling_plan_exclusion_tag     = "excludeFromScaling"
hostpool_custom_rdp_properties = "targetisaadjoined:i:1;audiocapturemode:i:1;audiomode:i:0;redirectclipboard:i:1;redirectprinters:i:1;drivestoredirect:s:*;"

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
    hostpool_private_endpoint_subnet_name  = "snet-itm-001-pe"
    session_host_configuration = {
      friendlyName = "ITM001 NPD session hosts"
      vmLocation   = "australiaeast"
      vmNamePrefix = "itm001"
      vmSizeId     = "Standard_D2s_v5"

      imageInfo = {
        type = "Marketplace"
        marketplaceInfo = {
          # publisher    = "MicrosoftWindowsServer"
          # offer        = "WindowsServer"
          # sku          = "2022-datacenter-azure-edition"
          # exactVersion = "20348.5499.260809"
          publisher    = "MicrosoftWindowsDesktop" # Windows 11 AVD image retained for reference.
          offer        = "windows-11"
          sku          = "win11-25h2-avd"
          exactVersion = "26200.9168.260809"
        }
      }

      domainInfo = {
        joinType = "AzureActiveDirectory"
      }

      vmTags = {
        environment = "npd"
        workload    = "avd001"
      }
    }
  },
  {
    name                                   = "pool-itm002"
    resource_group_name                    = "rg-pool-itm002-npd"
    avd_users_group                        = "avd_users_cloud"
    app_group_name                         = "app-itm002"
    app_group_type                         = "RemoteApp"
    app_group_default_desktop_display_name = "itm002"
    scaling_plan_name                      = "sp-itm002-npd"
    scaling_plan_friendly_name             = "ITM002 NPD Dynamic Autoscale"
    scaling_plan_description               = "Default dynamic autoscale plan for ITM002 NPD."
    session_host_subnet_name               = "snet-itm-002"
    hostpool_private_endpoint_subnet_name  = "snet-itm-002-pe"
    session_host_configuration = {
      friendlyName = "ITM002 NPD session hosts"
      vmLocation   = "australiaeast"
      vmNamePrefix = "itm002"
      vmSizeId     = "Standard_D2s_v5"

      imageInfo = {
        type = "Marketplace"
        marketplaceInfo = {
          publisher    = "MicrosoftWindowsServer"
          offer        = "WindowsServer"
          sku          = "2022-datacenter-azure-edition"
          exactVersion = "20348.5499.260809"
        }
      }

      domainInfo = {
        joinType = "AzureActiveDirectory"
      }

      vmTags = {
        environment = "npd"
        workload    = "avd002"
      }
    }

    remote_apps = [
      {
        name          = "server-manager"
        friendly_name = "Server Manager"
        description   = "Windows Server Manager remote app"
        path          = "C:\\Windows\\System32\\ServerManager.exe"
        icon_path     = "C:\\Windows\\System32\\ServerManager.exe"
      }
    ]
  }
]
