# ── FSLogix Storage — Premium FileStorage, AADKERB, Private Endpoint ──────────
# Depends on: 01-resource-groups (rg_storage_name), 02-network (pesubnet_id, vnet_id)
#
# Security posture:
#   - shared_access_key_enabled       = false  (Entra-only auth)
#   - public_network_access_enabled   = false  (private endpoint only)
#   - AADKERB authentication for FSLogix Kerberos tickets

data "azurerm_client_config" "current" {
  provider = azurerm.spoke
}

data "azuread_group" "avd_users" {
  display_name     = var.avd_users_group
  security_enabled = true
}

# ── User-Assigned Managed Identity ───────────────────────────────────────────
resource "azurerm_user_assigned_identity" "storage_mi" {
  provider            = azurerm.spoke
  name                = var.storage_managed_identity_name
  resource_group_name = var.rg_storage_name
  location            = var.avdLocation
  tags                = var.tags
}

# ── FSLogix Storage Account ───────────────────────────────────────────────────
resource "azapi_resource" "fslogix" {
  type      = "Microsoft.Storage/storageAccounts@2023-05-01"
  name      = var.storage_account_name
  parent_id = "/subscriptions/${var.spoke_subscription_id}/resourceGroups/${var.rg_storage_name}"
  location  = var.avdLocation
  tags      = var.tags

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.storage_mi.id]
  }

  body = {
    kind = "FileStorage"
    sku = {
      name = "Premium_LRS"
    }
    properties = {
      allowSharedKeyAccess     = false
      publicNetworkAccess      = "Disabled"
      minimumTlsVersion        = "TLS1_2"
      supportsHttpsTrafficOnly = true

      azureFilesIdentityBasedAuthentication = {
        directoryServiceOptions = "AADKERB"
      }
    }
  }

  lifecycle {
    prevent_destroy = false
  }
}

# ── FSLogix File Share ────────────────────────────────────────────────────────
resource "azurerm_storage_share" "fslogix" {
  provider           = azurerm.spoke
  name               = var.fslogix_share_name
  storage_account_id = azapi_resource.fslogix.id
  quota              = var.fslogix_share_quota_gb
  enabled_protocol   = "SMB"
}

# ── Private DNS Zone for Files (pre-existing in hub) ─────────────────────
data "azurerm_private_dns_zone" "file_dns" {
  provider            = azurerm.hub
  name                = "privatelink.file.core.windows.net"
  resource_group_name = var.hub_dns_zone_rg
}


# ── Private Endpoint ──────────────────────────────────────────────────────────
resource "azurerm_private_endpoint" "file_pe" {
  provider            = azurerm.spoke
  name                = var.file_private_endpoint_name
  resource_group_name = var.rg_storage_name
  location            = var.avdLocation
  subnet_id           = "/subscriptions/${var.spoke_subscription_id}/resourceGroups/${var.rg_network}/providers/Microsoft.Network/virtualNetworks/${var.vnet_name}/subnets/${var.pesubnet_files}"
  tags                = var.tags

  private_service_connection {
    name                           = var.file_private_service_connection_name
    private_connection_resource_id = azapi_resource.fslogix.id
    is_manual_connection           = false
    subresource_names              = ["file"]
  }

  private_dns_zone_group {
    name                 = var.file_private_dns_zone_group_name
    private_dns_zone_ids = [data.azurerm_private_dns_zone.file_dns.id]
  }

  depends_on = [azapi_resource.fslogix]
}

# ── Network Rules — deny all except PE subnet ─────────────────────────────────
resource "azurerm_storage_account_network_rules" "fslogix_rules" {
  provider                   = azurerm.spoke
  storage_account_id         = azapi_resource.fslogix.id
  default_action             = "Deny"
  bypass                     = ["AzureServices"]
  virtual_network_subnet_ids = ["/subscriptions/${var.spoke_subscription_id}/resourceGroups/${var.rg_network}/providers/Microsoft.Network/virtualNetworks/${var.vnet_name}/subnets/${var.pesubnet_files}"]
  depends_on                 = [azurerm_private_endpoint.file_pe]
}

# ── Storage File Data SMB Share Contributor on FSLogix Storage ────────────────
resource "azurerm_role_assignment" "fslogix_smb" {
  scope                = "${azapi_resource.fslogix.id}/fileServices/default/shares/${var.fslogix_share_name}"
  role_definition_name = "Storage File Data SMB Share Contributor"
  principal_id         = data.azuread_group.avd_users.object_id

  depends_on = [
    azurerm_storage_share.fslogix
  ]
}
