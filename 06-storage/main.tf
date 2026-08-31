# ── FSLogix Storage — Premium FileStorage, AADKERB, Private Endpoint ──────────
# Depends on: 01-resource-groups (rg_storage_name), 02-network (pesubnet_id, vnet_id)
#
# Security posture:
#   - shared_access_key_enabled       = false  (Entra-only auth)
#   - public_network_access_enabled   = false  (private endpoint only)
#   - AADKERB authentication for FSLogix Kerberos tickets

locals {
  shares = {
    for share in flatten([
      for storage_key, storage in var.storage_accounts : [
        for share_key, share in storage.shares : {
          resource_key            = "${storage_key}.${share_key}"
          storage_key             = storage_key
          share_key               = share_key
          name                    = share.name
          quota_gb                = share.quota_gb
          rbac_groups             = share.rbac_groups
          smb_role_assignments    = share.smb_role_assignments
          smb_admin_principal_ids = share.smb_admin_principal_ids
        }
      ]
    ]) : share.resource_key => share
  }

  legacy_share_rbac_assignments = {
    for assignment in flatten([
      for share_resource_key, share in local.shares : [
        for group_name in share.rbac_groups : {
          resource_key         = "${share_resource_key}.${group_name}"
          share_resource_key   = share_resource_key
          storage_key          = share.storage_key
          share_name           = share.name
          group_name           = group_name
          role_definition_name = "Storage File Data SMB Share Contributor"
        }
      ]
    ]) : assignment.resource_key => assignment
  }

  rbac_group_names = toset([
    for assignment in values(local.legacy_share_rbac_assignments) : assignment.group_name
  ])

  direct_share_rbac_assignments = {
    for assignment in flatten([
      for share_resource_key, share in local.shares : [
        for assignment_key, assignment in share.smb_role_assignments : {
          resource_key         = "${share_resource_key}.${assignment_key}"
          share_resource_key   = share_resource_key
          storage_key          = share.storage_key
          share_name           = share.name
          principal_id         = assignment.principal_id
          role_definition_name = assignment.role_definition_name
        }
      ]
    ]) : assignment.resource_key => assignment
  }

  share_rbac_assignments = merge(
    {
      for key, assignment in local.legacy_share_rbac_assignments : key => {
        share_resource_key   = assignment.share_resource_key
        storage_key          = assignment.storage_key
        share_name           = assignment.share_name
        principal_id         = data.azuread_group.rbac_groups[assignment.group_name].object_id
        role_definition_name = assignment.role_definition_name
      }
    },
    local.direct_share_rbac_assignments
  )

  share_smb_admin_assignments = {
    for assignment in flatten([
      for share_resource_key, share in local.shares : [
        for assignment_key, principal_id in share.smb_admin_principal_ids : {
          resource_key       = "${share_resource_key}.${assignment_key}"
          share_resource_key = share_resource_key
          storage_key        = share.storage_key
          share_name         = share.name
          principal_id       = principal_id
        }
      ]
    ]) : assignment.resource_key => assignment
  }
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

      azureFilesIdentityBasedAuthentication = merge(
        {
          directoryServiceOptions = each.value.identity_auth_directory_service
        },
        var.active_directory_domain_name != null && var.active_directory_domain_guid != null ? {
          activeDirectoryProperties = {
            domainName = var.active_directory_domain_name
            domainGuid = var.active_directory_domain_guid
          }
        } : {}
      )
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

# ── Share-level SMB RBAC ──────────────────────────────────────────────────────
resource "azurerm_role_assignment" "share_smb" {
  for_each = local.share_rbac_assignments

  provider             = azurerm.spoke
  scope                = azapi_resource.shares[each.value.share_resource_key].id
  role_definition_name = each.value.role_definition_name
  principal_id         = each.value.principal_id

  depends_on = [
    azapi_resource.shares
  ]
}

# ── Storage File Data SMB Admin for ACL administrators ────────────────────────
# This is intentionally separate from normal share access because it allows
# ownership and ACL administration over SMB.
resource "azurerm_role_assignment" "share_smb_admin" {
  for_each = local.share_smb_admin_assignments

  provider             = azurerm.spoke
  scope                = azapi_resource.shares[each.value.share_resource_key].id
  role_definition_name = "Storage File Data SMB Admin"
  principal_id         = each.value.principal_id

  depends_on = [
    azapi_resource.shares
  ]
}
