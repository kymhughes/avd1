# ── AVD common service objects including resource group and Workspace ─────────────────

resource "azurerm_resource_group" "service_objects" {
  location = var.avdLocation
  name     = var.rg_so
  tags     = var.tags
  lifecycle { prevent_destroy = false }
}

data "azurerm_client_config" "current" {}

data "azuread_group" "avd_users" {
  display_name     = var.user_group_name
  security_enabled = true
}

resource "random_string" "suffix" {
  length  = 4
  special = false
  upper   = false
}

# ── Workspace (AVM v0.2.2) ────────────────────────────────────────────────────
module "avm_res_desktopvirtualization_workspace" {
  source  = "Azure/avm-res-desktopvirtualization-workspace/azurerm"
  version = "0.2.2"

  virtual_desktop_workspace_name                = var.workspace_name
  virtual_desktop_workspace_resource_group_name = data.azurerm_resource_group.service_objects.name
  virtual_desktop_workspace_location            = var.avdLocation
  virtual_desktop_workspace_tags                = var.tags
  enable_telemetry                              = var.enable_telemetry
  public_network_access_enabled                 = false
}

# ── Private DNS Zone for AVD Workspace feed (pre-existing in hub) ────────────
data "azurerm_private_dns_zone" "avd_feed_dns" {
  provider            = azurerm.hub
  name                = "privatelink.wvd.microsoft.com"
  resource_group_name = var.hub_dns_zone_rg
}

# ── Workspace Private Endpoint (feed) ───────────────────────────────────
resource "azurerm_private_endpoint" "workspace_pe" {
  name                = "pe-avd-ws-${var.prefix}"
  resource_group_name = data.azurerm_resource_group.service_objects.name
  location            = var.avdLocation
  subnet_id           = "/subscriptions/${var.spoke_subscription_id}/resourceGroups/${var.rg_network}/providers/Microsoft.Network/virtualNetworks/${var.vnet_name}/subnets/${var.pesubnet_workspace}"
  tags                = var.tags

  private_service_connection {
    name                           = "psc-ws-${var.prefix}"
    private_connection_resource_id = module.avm_res_desktopvirtualization_workspace.resource.id
    is_manual_connection           = false
    subresource_names              = ["feed"]
  }

  private_dns_zone_group {
    name                 = "dns-ws-${var.prefix}"
    private_dns_zone_ids = [data.azurerm_private_dns_zone.avd_feed_dns.id]
  }

  depends_on = [module.avm_res_desktopvirtualization_workspace]
  lifecycle { prevent_destroy = false }
}
