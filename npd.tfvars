# 01-resource-groups — npd environment
avdLocation                            = "australiaeast"
tenant_id                              = "dc21babb-d49a-4fae-8763-b7e24c721aca"
prefix                                 = "it01"
environment                            = "npd"
spoke_subscription_id                  = "e4ea360b-bf76-47bc-bb09-81bd23faad9e"
hub_subscription_id                    = "eb60ae18-0772-4810-8616-c189bb571c25"
rg_network                             = "rg-itm-network-npd"
rg_so                                  = "rg-it01-service-objects-npd"
rg_stor                                = "rg-it01-storage-npd"
rg_pool                                = "rg-it01-pool-npd"
hub_dns_zone_rg                        = "rg-adds"
hub_connectivity_rg                    = "rg-hub1"
hub_vnet                               = "vnet-auea-hub1"
vnet_name                              = "vnet-itm-vnet-npd"
vnet_range                             = ["172.17.100.0/23"]
dns_servers                            = ["172.17.10.4"]
keyvault_name                          = "kv-avd-it01-npd"
user_group_name                        = "avd_users_cloud"
hostpool_name                          = "pool-itm001"
workspace_name                         = "workspace-itm"
app_group_name                         = "app-itm001"
app_group_default_desktop_display_name = "itm001"
scplan_name                            = "vdscaling"
scaling_plan_sp_id                     = "6774ae85-d784-4d45-9585-876477e8f6b7"
enable_telemetry                       = false
pesubnet_id                            = "/subscriptions/e4ea360b-bf76-47bc-bb09-81bd23faad9e/resourceGroups/rg-itm-network-npd/providers/Microsoft.Network/virtualNetworks/vnet-itm-vnet-npd/subnets/snet-itm-001-pe"
pesubnet_avdglobal                     = "snet-general-pe"
pesubnet_workspace                     = "snet-general-pe"
pesubnet_keyvault                      = "snet-general-pe"
pesubnet_hostpool1                     = "snet-itm-001-pe"
hostpool_start_vm_on_connect           = true
hostpool_validate_environment          = true
hostpool_custom_rdp_properties         = "audiocapturemode:i:1;audiomode:i:0;redirectclipboard:i:1;redirectprinters:i:1;drivestoredirect:s:*;"

host_pool_log_categories = [
  "Checkpoint", "Error", "Management", "Connection",
  "HostRegistration", "AgentHealthStatus", "NetworkData",
  "SessionHostManagement", "ConnectionGraphicsData"
]
dag_log_categories = ["Checkpoint", "Error", "Management"]
ws_log_categories  = ["Checkpoint", "Error", "Management", "Feed"]

tags = {
  environment = "npd"
  workload    = "network"
  owner       = "platform"
  costCenter  = "shared"
  managedBy   = "terraform"
}


subnets = {
  "snet-itm-001" = {
    name                              = "itm001"
    address_prefixes                  = ["172.17.100.0/28"]
    private_subnet_enabled            = true
    private_endpoint_network_policies = "Disabled"
    #service_endpoints      = ["Microsoft.Storage", "Microsoft.KeyVault"]
    nsg = {
      #existing_network_security_group_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-shared-network/providers/Microsoft.Network/networkSecurityGroups/nsg-shared"
      create = true
      security_rules = {
        "Allow-HTTPS-Inbound" = {
          priority                   = 100
          direction                  = "Inbound"
          access                     = "Allow"
          protocol                   = "Tcp"
          source_address_prefix      = "VirtualNetwork"
          destination_address_prefix = "*"
          destination_port_range     = "443"
        }
        "Allow-any-Outbound" = {
          priority                   = 110
          direction                  = "Outbound"
          access                     = "Allow"
          protocol                   = "all"
          source_address_prefix      = "VirtualNetwork"
          destination_address_prefix = "*"
          destination_port_range     = "*"
        }
      }
    }
  }

  "snet-itm-001-pe" = {
    address_prefixes                  = ["172.17.101.0/28"]
    private_subnet_enabled            = true
    private_endpoint_network_policies = "Enabled"
    nsg = {
      #existing_network_security_group_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-shared-network/providers/Microsoft.Network/networkSecurityGroups/nsg-shared"
      create = true
      security_rules = {
        "Allow-HTTPS-Inbound" = {
          priority                   = 100
          direction                  = "Inbound"
          access                     = "Allow"
          protocol                   = "Tcp"
          source_address_prefix      = "VirtualNetwork"
          destination_address_prefix = "*"
          destination_port_range     = "443"
        }
      }
    }
  }

  "snet-itm-002" = {
    name                              = "itm002"
    address_prefixes                  = ["172.17.100.16/28"]
    private_subnet_enabled            = true
    private_endpoint_network_policies = "Disabled"
    nsg                               = { create = true }
  }

  "snet-itm-002-pe" = {
    address_prefixes                  = ["172.17.101.16/28"]
    private_subnet_enabled            = true
    private_endpoint_network_policies = "Enabled"
    nsg                               = { create = true }
  }


  "snet-general-pe" = {
    name                              = "general"
    address_prefixes                  = ["172.17.100.240/28"]
    private_subnet_enabled            = true
    private_endpoint_network_policies = "Enabled"
    nsg = {
      create = true
      security_rules = {
        "Allow-HTTPS-Inbound" = {
          priority                   = 100
          direction                  = "Inbound"
          access                     = "Allow"
          protocol                   = "Tcp"
          source_address_prefix      = "VirtualNetwork"
          destination_address_prefix = "*"
          destination_port_range     = "443"
        }
      }
    }
  }
}
