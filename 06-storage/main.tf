# ── FSLogix Storage — Premium FileStorage, AADKERB, Private Endpoint ──────────
# Depends on: 01-resource-groups (rg_storage_name), 02-network (pesubnet_id, vnet_id)
# Provides:   storage_account_id, storage_account_name, fslogix_share_name
#             → consumed by 08-rbac
#
# Security posture:
#   - shared_access_key_enabled       = false  (Entra-only auth)
#   - public_network_access_enabled   = false  (private endpoint only)
#   - AADKERB authentication for FSLogix Kerberos tickets

data "azurerm_client_config" "current" {
  provider = azurerm.spoke
}

resource "random_string" "suffix" {
  length  = 4
  special = false
  upper   = false
}

locals {
  storage_name = lower(replace("stavd${var.prefix}${random_string.suffix.id}", "-", ""))
  tags = {
    environment     = var.environment
    ServiceWorkload = "Azure Virtual Desktop"
    ManagedBy       = "Terraform"
  }
}

# ── User-Assigned Managed Identity ───────────────────────────────────────────
resource "azurerm_user_assigned_identity" "storage_mi" {
  provider            = azurerm.spoke
  name                = "mi-avd-storage-${var.prefix}-${var.environment}"
  resource_group_name = var.rg_storage_name
  location            = var.avdLocation
  tags                = local.tags
}

# ── FSLogix Storage Account ───────────────────────────────────────────────────
resource "azurerm_storage_account" "fslogix" {
  provider                      = azurerm.spoke
  name                          = local.storage_name
  resource_group_name           = var.rg_storage_name
  location                      = var.avdLocation
  account_tier                  = "Premium"
  account_kind                  = "FileStorage"
  account_replication_type      = "LRS"
  shared_access_key_enabled     = false
  public_network_access_enabled = false
  min_tls_version               = "TLS1_2"
  tags                          = local.tags

  azure_files_authentication {
    directory_type = "AADKERB"
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.storage_mi.id]
  }

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [azure_files_authentication]
  }
}

# ── FSLogix File Share ────────────────────────────────────────────────────────
resource "azurerm_storage_share" "fslogix" {
  provider           = azurerm.spoke
  name               = "fslogix"
  storage_account_id = azurerm_storage_account.fslogix.id
  quota              = var.fslogix_share_quota_gb
  enabled_protocol   = "SMB"
}

# ── Private DNS Zone for Files (pre-existing in hub) ─────────────────────
# DNS zones are managed centrally by the platform/hub team — reference only.
# Prerequisite: "privatelink.file.core.windows.net" zone must already exist in
# var.hub_dns_zone_rg before running this module.
# If previously managed by this module, remove from state first:
#   terraform state rm azurerm_private_dns_zone.file_dns
data "azurerm_private_dns_zone" "file_dns" {
  provider            = azurerm.hub
  name                = "privatelink.file.core.windows.net"
  resource_group_name = var.hub_dns_zone_rg
}

# VNet link — connects spoke VNet to the hub DNS zone so DNS queries resolve privately.
# Created once per spoke VNet; prevent_destroy ensures it is never accidentally removed.
resource "azurerm_private_dns_zone_virtual_network_link" "file_dns_link" {
  provider              = azurerm.hub
  name                  = "link-files-${var.prefix}"
  resource_group_name   = var.hub_dns_zone_rg
  private_dns_zone_name = data.azurerm_private_dns_zone.file_dns.name
  virtual_network_id    = var.spoke_vnet_id
  registration_enabled  = false
  tags                  = local.tags
  lifecycle { prevent_destroy = true }
}

# ── Private Endpoint ──────────────────────────────────────────────────────────
resource "azurerm_private_endpoint" "file_pe" {
  provider            = azurerm.spoke
  name                = "pe-avd-files-${var.prefix}"
  resource_group_name = var.rg_storage_name
  location            = var.avdLocation
  subnet_id           = var.pesubnet_id
  tags                = local.tags

  private_service_connection {
    name                           = "psc-files-${var.prefix}"
    private_connection_resource_id = azurerm_storage_account.fslogix.id
    is_manual_connection           = false
    subresource_names              = ["file"]
  }

  private_dns_zone_group {
    name                 = "dns-file-${var.prefix}"
    private_dns_zone_ids = [data.azurerm_private_dns_zone.file_dns.id]
  }

  depends_on = [azurerm_storage_account.fslogix]
}

# ── Network Rules — deny all except PE subnet ─────────────────────────────────
resource "azurerm_storage_account_network_rules" "fslogix_rules" {
  provider                   = azurerm.spoke
  storage_account_id         = azurerm_storage_account.fslogix.id
  default_action             = "Deny"
  bypass                     = ["AzureServices"]
  virtual_network_subnet_ids = [var.pesubnet_id]
  depends_on                 = [azurerm_private_endpoint.file_pe]
}
