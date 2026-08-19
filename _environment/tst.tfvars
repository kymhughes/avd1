# Shared values for the npd environment.
avdLocation           = "australiaeast"
tenant_id             = "dc21babb-d49a-4fae-8763-b7e24c721aca"
prefix                = "it01"
environment           = "npd"
spoke_subscription_id = "e4ea360b-bf76-47bc-bb09-81bd23faad9e"
hub_subscription_id   = "eb60ae18-0772-4810-8616-c189bb571c25"
hub_dns_zone_rg       = "rg-adds"
enable_telemetry      = false

tags = {
  environment = "npd"
  workload    = "network"
  owner       = "platform"
  costCenter  = "shared"
  managedBy   = "terraform"
}
