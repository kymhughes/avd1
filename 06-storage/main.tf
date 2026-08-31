# ── Storage Accounts — parent orchestration ───────────────────────────────────
# One child module instance owns one storage account and its shares/RBAC.

data "azurerm_private_dns_zone" "file_dns" {
  provider            = azurerm.hub
  name                = "privatelink.file.core.windows.net"
  resource_group_name = var.hub_dns_zone_rg
}

module "storage_account" {
  for_each = var.storage_accounts

  source = "./modules/storage-account"

  providers = {
    azurerm.spoke = azurerm.spoke
    azapi         = azapi
    azuread       = azuread
  }

  storage_key     = each.key
  storage_account = each.value

  avdLocation           = var.avdLocation
  spoke_subscription_id = var.spoke_subscription_id
  rg_storage_name       = var.rg_storage_name
  rg_network            = var.rg_network
  vnet_name             = var.vnet_name
  pesubnet_files        = var.pesubnet_files
  private_dns_zone_id   = data.azurerm_private_dns_zone.file_dns.id
  tags                  = var.tags

  active_directory_domain_name = var.active_directory_domain_name
  active_directory_domain_guid = var.active_directory_domain_guid
}
