# Creates common AVD service objects shared by host pools.
# The workspace and its feed private endpoint are deployed here so host pool
# modules can focus on app groups, session host automation, and scaling.

resource "azurerm_resource_group" "service_objects" {
  location = var.avdLocation
  name     = var.rg_so
  tags     = var.tags
  lifecycle { prevent_destroy = false }
}

data "azurerm_client_config" "current" {}

resource "random_string" "suffix" {
  length  = 4
  special = false
  upper   = false
}

# AVD workspace is private-only; users reach the feed through the private
# endpoint below rather than through public network access.
module "avm_res_desktopvirtualization_workspace" {
  source  = "Azure/avm-res-desktopvirtualization-workspace/azurerm"
  version = "0.2.2"

  virtual_desktop_workspace_name                = var.workspace_name
  virtual_desktop_workspace_resource_group_name = azurerm_resource_group.service_objects.name
  virtual_desktop_workspace_location            = var.avdLocation
  virtual_desktop_workspace_tags                = var.tags
  enable_telemetry                              = false
  public_network_access_enabled                 = false
}

# The private DNS zone is owned by the hub subscription and must already exist.
data "azurerm_private_dns_zone" "avd_feed_dns" {
  provider            = azurerm.hub
  name                = "privatelink.wvd.microsoft.com"
  resource_group_name = var.hub_dns_zone_rg
}

# The feed subresource publishes the workspace feed privately through the spoke
# private endpoint subnet while registering DNS records in the hub zone.
resource "azurerm_private_endpoint" "workspace_pe" {
  name                = var.workspace_pe_name
  resource_group_name = azurerm_resource_group.service_objects.name
  location            = var.avdLocation
  subnet_id           = "/subscriptions/${var.spoke_subscription_id}/resourceGroups/${var.rg_network}/providers/Microsoft.Network/virtualNetworks/${var.vnet_name}/subnets/${var.pesubnet_workspace}"
  tags                = var.tags

  private_service_connection {
    name                           = var.workspace_sc_name
    private_connection_resource_id = module.avm_res_desktopvirtualization_workspace.resource.id
    is_manual_connection           = false
    subresource_names              = ["feed"]
  }

  private_dns_zone_group {
    name                 = var.workspace_dns_zone_group_name
    private_dns_zone_ids = [data.azurerm_private_dns_zone.avd_feed_dns.id]
  }

  depends_on = [module.avm_res_desktopvirtualization_workspace]
  lifecycle { prevent_destroy = false }
}

###################################################################################
# Assign necessary subscription-level roles to the AVD service principal for
# dynamic autoscale/session host configuration.
###################################################################################
resource "azurerm_role_assignment" "avd_reader" {
  scope                            = "/subscriptions/${var.spoke_subscription_id}"
  role_definition_name             = "Reader"
  principal_id                     = var.avd_service_principal_object_id
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "avd_vm_on_off_contributor" {
  scope                            = "/subscriptions/${var.spoke_subscription_id}"
  role_definition_name             = "Desktop Virtualization Power On Off Contributor"
  principal_id                     = var.avd_service_principal_object_id
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "avd_vm_contributor" {
  scope                            = "/subscriptions/${var.spoke_subscription_id}"
  role_definition_name             = "Desktop Virtualization Virtual Machine Contributor"
  principal_id                     = var.avd_service_principal_object_id
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "avd_network_contributor" {
  scope                            = "/subscriptions/${var.spoke_subscription_id}"
  role_definition_name             = "Network Contributor"
  principal_id                     = var.avd_service_principal_object_id
  skip_service_principal_aad_check = true
}


# data "azuread_group" "avd_users" {
#   display_name     = var.user_group_name
#   security_enabled = true
# }
