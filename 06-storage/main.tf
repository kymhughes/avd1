# ── FSLogix Storage — Premium FileStorage, AADKERB, Private Endpoint ──────────
# Depends on: 01-resource-groups (rg_storage_name), 02-network (pesubnet_id, vnet_id)
#
# Security posture:
#   - shared_access_key_enabled       = false  (Entra-only auth)
#   - public_network_access_enabled   = false  (private endpoint only)
#   - AADKERB authentication for FSLogix Kerberos tickets

locals {
  shares = merge([
    for storage_key, storage in var.storage_accounts : {
      for share_key, share in storage.shares : "${storage_key}.${share_key}" => {
        storage_key = storage_key
        share_key   = share_key
        name        = share.name
        quota_gb    = share.quota_gb
        rbac_groups = share.rbac_groups
      }
    }
  ]...)

  share_rbac_assignments = merge([
    for share_resource_key, share in local.shares : {
      for group_name in share.rbac_groups : "${share_resource_key}.${group_name}" => {
        share_resource_key = share_resource_key
        storage_key        = share.storage_key
        share_name         = share.name
        group_name         = group_name
      }
    }
  ]...)

  rbac_group_names = toset([
    for assignment in values(local.share_rbac_assignments) : assignment.group_name
  ])
}

data "azuread_group" "rbac_groups" {
  for_each = local.rbac_group_names

  display_name     = each.key
  security_enabled = true
}

# ── User-Assigned Managed Identity ───────────────────────────────────────────
resource "azurerm_user_assigned_identity" "storage_mi" {
  for_each = var.storage_accounts

  provider            = azurerm.spoke
  name                = each.value.managed_identity_name
  resource_group_name = var.rg_storage_name
  location            = var.avdLocation
  tags                = var.tags
}

# ── FSLogix Storage Account ───────────────────────────────────────────────────
resource "azapi_resource" "storage_account" {
  for_each = var.storage_accounts

  type      = "Microsoft.Storage/storageAccounts@2023-05-01"
  name      = each.value.name
  parent_id = "/subscriptions/${var.spoke_subscription_id}/resourceGroups/${var.rg_storage_name}"
  location  = var.avdLocation
  tags      = var.tags

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.storage_mi[each.key].id]
  }

  body = {
    kind = each.value.kind
    sku = {
      name = each.value.sku_name
    }
    properties = {
      allowSharedKeyAccess     = false
      publicNetworkAccess      = "Disabled"
      minimumTlsVersion        = "TLS1_2"
      supportsHttpsTrafficOnly = true

      azureFilesIdentityBasedAuthentication = {
        directoryServiceOptions = each.value.identity_auth_directory_service
      }
    }
  }

  lifecycle {
    prevent_destroy = false
  }
}

# ── Azure Files Shares ────────────────────────────────────────────────────────
resource "azapi_resource" "shares" {
  for_each = local.shares

  type      = "Microsoft.Storage/storageAccounts/fileServices/shares@2023-05-01"
  name      = each.value.name
  parent_id = "${azapi_resource.storage_account[each.value.storage_key].id}/fileServices/default"

  body = {
    properties = {
      shareQuota       = each.value.quota_gb
      enabledProtocols = "SMB"
    }
  }
}

# ── Private DNS Zone for Files (pre-existing in hub) ─────────────────────
data "azurerm_private_dns_zone" "file_dns" {
  provider            = azurerm.hub
  name                = "privatelink.file.core.windows.net"
  resource_group_name = var.hub_dns_zone_rg
}


# ── Private Endpoint ──────────────────────────────────────────────────────────
resource "azurerm_private_endpoint" "file_pe" {
  for_each = var.storage_accounts

  provider            = azurerm.spoke
  name                = each.value.private_endpoint_name
  resource_group_name = var.rg_storage_name
  location            = var.avdLocation
  subnet_id           = "/subscriptions/${var.spoke_subscription_id}/resourceGroups/${var.rg_network}/providers/Microsoft.Network/virtualNetworks/${var.vnet_name}/subnets/${var.pesubnet_files}"
  tags                = var.tags

  private_service_connection {
    name                           = each.value.private_service_connection_name
    private_connection_resource_id = azapi_resource.storage_account[each.key].id
    is_manual_connection           = false
    subresource_names              = ["file"]
  }

  private_dns_zone_group {
    name                 = each.value.private_dns_zone_group_name
    private_dns_zone_ids = [data.azurerm_private_dns_zone.file_dns.id]
  }

  depends_on = [azapi_resource.storage_account]
}

# ── Network Rules — deny all except PE subnet ─────────────────────────────────
resource "azurerm_storage_account_network_rules" "fslogix_rules" {
  for_each = var.storage_accounts

  provider           = azurerm.spoke
  storage_account_id = azapi_resource.storage_account[each.key].id
  default_action     = "Deny"
  bypass             = ["AzureServices"]
  depends_on         = [azurerm_private_endpoint.file_pe]
}

# ── Storage File Data SMB Share Contributor on FSLogix Storage ────────────────
resource "azurerm_role_assignment" "share_smb" {
  for_each = local.share_rbac_assignments

  provider             = azurerm.spoke
  scope                = "${azapi_resource.storage_account[each.value.storage_key].id}/fileServices/default/shares/${each.value.share_name}"
  role_definition_name = "Storage File Data SMB Share Contributor"
  principal_id         = data.azuread_group.rbac_groups[each.value.group_name].object_id

  depends_on = [
    azapi_resource.shares
  ]
}
