locals {
  share_rbac_assignments = {
    for assignment in flatten([
      for share_key, share in var.storage_account.shares : [
        for assignment_key, assignment in share.smb_role_assignments : {
          resource_key         = "${share_key}.${assignment_key}"
          share_key            = share_key
          group_name           = assignment.group_name
          role_definition_name = assignment.role_definition_name
        }
      ]
    ]) : assignment.resource_key => assignment
  }

  share_smb_admin_assignments = {
    for assignment in flatten([
      for share_key, share in var.storage_account.shares : [
        for group_name in share.smb_admin_groups : {
          resource_key = "${share_key}.${group_name}"
          share_key    = share_key
          group_name   = group_name
        }
      ]
    ]) : assignment.resource_key => assignment
  }

  rbac_group_names = toset(concat(
    [for assignment in values(local.share_rbac_assignments) : assignment.group_name],
    [for assignment in values(local.share_smb_admin_assignments) : assignment.group_name]
  ))
}

data "azuread_group" "rbac_groups" {
  for_each = local.rbac_group_names

  display_name     = each.key
  security_enabled = true
}

resource "azurerm_user_assigned_identity" "storage_mi" {
  provider            = azurerm.spoke
  name                = var.storage_account.managed_identity_name
  resource_group_name = var.rg_storage_name
  location            = var.avdLocation
  tags                = var.tags
}

resource "azapi_resource" "storage_account" {
  type      = "Microsoft.Storage/storageAccounts@2023-05-01"
  name      = var.storage_account.name
  parent_id = "/subscriptions/${var.spoke_subscription_id}/resourceGroups/${var.rg_storage_name}"
  location  = var.avdLocation
  tags      = var.tags

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.storage_mi.id]
  }

  body = {
    kind = var.storage_account.kind
    sku = {
      name = var.storage_account.sku_name
    }
    properties = {
      allowSharedKeyAccess     = false
      publicNetworkAccess      = "Disabled"
      minimumTlsVersion        = "TLS1_2"
      supportsHttpsTrafficOnly = true

      azureFilesIdentityBasedAuthentication = merge(
        {
          directoryServiceOptions = var.storage_account.identity_auth_directory_service
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

resource "azapi_resource" "shares" {
  for_each = var.storage_account.shares

  type      = "Microsoft.Storage/storageAccounts/fileServices/shares@2023-05-01"
  name      = each.value.name
  parent_id = "${azapi_resource.storage_account.id}/fileServices/default"

  body = {
    properties = {
      shareQuota       = each.value.quota_gb
      enabledProtocols = "SMB"
    }
  }
}

resource "azurerm_private_endpoint" "file_pe" {
  provider            = azurerm.spoke
  name                = var.storage_account.private_endpoint_name
  resource_group_name = var.rg_storage_name
  location            = var.avdLocation
  subnet_id           = "/subscriptions/${var.spoke_subscription_id}/resourceGroups/${var.rg_network}/providers/Microsoft.Network/virtualNetworks/${var.vnet_name}/subnets/${var.pesubnet_files}"
  tags                = var.tags

  private_service_connection {
    name                           = var.storage_account.private_service_connection_name
    private_connection_resource_id = azapi_resource.storage_account.id
    is_manual_connection           = false
    subresource_names              = ["file"]
  }

  private_dns_zone_group {
    name                 = var.storage_account.private_dns_zone_group_name
    private_dns_zone_ids = [var.private_dns_zone_id]
  }
}

resource "azurerm_storage_account_network_rules" "storage_rules" {
  provider           = azurerm.spoke
  storage_account_id = azapi_resource.storage_account.id
  default_action     = "Deny"
  bypass             = ["AzureServices"]
  depends_on         = [azurerm_private_endpoint.file_pe]
}

resource "azurerm_role_assignment" "share_smb" {
  for_each = local.share_rbac_assignments

  provider             = azurerm.spoke
  scope                = azapi_resource.shares[each.value.share_key].id
  role_definition_name = each.value.role_definition_name
  principal_id         = data.azuread_group.rbac_groups[each.value.group_name].object_id

  depends_on = [
    azapi_resource.shares
  ]
}

resource "azurerm_role_assignment" "share_smb_admin" {
  for_each = local.share_smb_admin_assignments

  provider             = azurerm.spoke
  scope                = azapi_resource.shares[each.value.share_key].id
  role_definition_name = "Storage File Data SMB Admin"
  principal_id         = data.azuread_group.rbac_groups[each.value.group_name].object_id

  depends_on = [
    azapi_resource.shares
  ]
}
