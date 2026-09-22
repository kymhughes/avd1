# Shared values for the npd environment.
avdLocation                     = "australiaeast"
tenant_id                       = "dc21babb-d49a-4fae-8763-b7e24c721aca"
environment                     = "npd"
spoke_subscription_id           = "e4ea360b-bf76-47bc-bb09-81bd23faad9e"
hub_subscription_id             = "eb60ae18-0772-4810-8616-c189bb571c25"
hub_dns_zone_rg                 = "rg-adds"
rg_network                      = "rg-itm-network-npd"
vnet_name                       = "vnet-itm-vnet-npd"
rg_so                           = "rg-service-objects-npd"
workspace_name                  = "workspace-npd"
rg_storage_name                 = "rg-service-objects-npd"
pesubnet_workspace              = "snet-general-pe"
pesubnet_keyvault               = "snet-general-pe"
pesubnet_files                  = "snet-general-pe"
avd_service_principal_object_id = "66080947-954d-4adb-933c-293d3bbb3441"

tags = {
  environment = "npd"
  workload    = "network"
  owner       = "platform"
  costCenter  = "shared"
  managedBy   = "terraform"
}
