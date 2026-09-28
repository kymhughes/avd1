# Creates private storage for FSLogix profiles and general blob workloads.
# Both storage accounts are locked down to private endpoints and use managed
# identities, with FSLogix SMB access granted to the configured Entra group.

data "azurerm_private_dns_zone" "file_dns" {
  provider            = azurerm.hub
  name                = "privatelink.file.core.windows.net"
  resource_group_name = var.hub_dns_zone_rg
}

data "azurerm_private_dns_zone" "blob_dns" {
  provider            = azurerm.hub
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = var.hub_dns_zone_rg
}

data "azuread_group" "fslogix_users" {
  display_name     = var.fslogix_users_group
  security_enabled = true
}

data "azurerm_key_vault" "storage_cmk" {
  count = var.storage_cmk_enabled ? 1 : 0

  provider            = azurerm.spoke
  name                = var.storage_cmk_key_vault_name
  resource_group_name = coalesce(var.storage_cmk_key_vault_resource_group_name, var.rg_so)
}

resource "azurerm_user_assigned_identity" "fslogix" {
  provider            = azurerm.spoke
  name                = var.fslogix_managed_identity_name
  resource_group_name = var.rg_storage_name
  location            = var.avdLocation
  tags                = var.tags
}

resource "azurerm_user_assigned_identity" "general" {
  provider            = azurerm.spoke
  name                = var.general_managed_identity_name
  resource_group_name = var.rg_storage_name
  location            = var.avdLocation
  tags                = var.tags
}

resource "azurerm_role_assignment" "fslogix_storage_cmk" {
  count = var.storage_cmk_enabled ? 1 : 0

  provider             = azurerm.spoke
  scope                = data.azurerm_key_vault.storage_cmk[0].id
  role_definition_name = "Key Vault Crypto Service Encryption User"
  principal_id         = azurerm_user_assigned_identity.fslogix.principal_id
}

resource "azurerm_role_assignment" "general_storage_cmk" {
  count = var.storage_cmk_enabled ? 1 : 0

  provider             = azurerm.spoke
  scope                = data.azurerm_key_vault.storage_cmk[0].id
  role_definition_name = "Key Vault Crypto Service Encryption User"
  principal_id         = azurerm_user_assigned_identity.general.principal_id
}

locals {
  fslogix_storage_cmk_encryption = var.storage_cmk_enabled ? {
    encryption = {
      keySource = "Microsoft.Keyvault"
      keyvaultproperties = {
        keyname     = var.storage_cmk_key_name
        keyvaulturi = data.azurerm_key_vault.storage_cmk[0].vault_uri
      }
      identity = {
        userAssignedIdentity = azurerm_user_assigned_identity.fslogix.id
      }
    }
  } : {}

  general_storage_cmk_encryption = var.storage_cmk_enabled ? {
    encryption = {
      keySource = "Microsoft.Keyvault"
      keyvaultproperties = {
        keyname     = var.storage_cmk_key_name
        keyvaulturi = data.azurerm_key_vault.storage_cmk[0].vault_uri
      }
      identity = {
        userAssignedIdentity = azurerm_user_assigned_identity.general.id
      }
    }
  } : {}
}

# AzAPI is used here to control storage account properties that can lag in the
# AzureRM provider, especially identity-based Azure Files authentication.
resource "azapi_resource" "fslogix_storage" {
  type      = "Microsoft.Storage/storageAccounts@2023-05-01"
  name      = var.fslogix_storage_account_name
  parent_id = "/subscriptions/${var.spoke_subscription_id}/resourceGroups/${var.rg_storage_name}"
  location  = var.avdLocation
  tags      = var.tags

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.fslogix.id]
  }

  body = {
    kind = "FileStorage"
    sku = {
      name = "Premium_LRS"
    }
    properties = merge(
      {
        allowSharedKeyAccess     = false
        publicNetworkAccess      = "Disabled"
        minimumTlsVersion        = "TLS1_2"
        supportsHttpsTrafficOnly = true
      },
      # Only emit the Azure Files identity auth block when an auth mode is set;
      # AD DS properties are all-or-nothing and are validated in variables.tf.
      var.fslogix_identity_auth_directory_service != null ? {
        azureFilesIdentityBasedAuthentication = merge(
          {
            directoryServiceOptions = var.fslogix_identity_auth_directory_service
          },
          var.active_directory_domain_name != null && var.active_directory_domain_guid != null ? {
            activeDirectoryProperties = {
              domainName = var.active_directory_domain_name
              domainGuid = var.active_directory_domain_guid
            }
          } : {}
        )
      } : {},
      local.fslogix_storage_cmk_encryption
    )
  }

  depends_on = [
    azurerm_role_assignment.fslogix_storage_cmk
  ]
}

resource "azapi_resource" "fslogix_share" {
  type      = "Microsoft.Storage/storageAccounts/fileServices/shares@2023-05-01"
  name      = var.fslogix_share_name
  parent_id = "${azapi_resource.fslogix_storage.id}/fileServices/default"

  body = {
    properties = {
      shareQuota       = var.fslogix_share_quota_gb
      enabledProtocols = "SMB"
    }
  }
}

resource "azapi_resource" "general_storage" {
  type      = "Microsoft.Storage/storageAccounts@2023-05-01"
  name      = var.general_storage_account_name
  parent_id = "/subscriptions/${var.spoke_subscription_id}/resourceGroups/${var.rg_storage_name}"
  location  = var.avdLocation
  tags      = var.tags

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.general.id]
  }

  body = {
    kind = "StorageV2"
    sku = {
      name = "Standard_LRS"
    }
    properties = merge(
      {
        allowSharedKeyAccess     = false
        publicNetworkAccess      = "Disabled"
        minimumTlsVersion        = "TLS1_2"
        supportsHttpsTrafficOnly = true
      },
      local.general_storage_cmk_encryption
    )
  }

  depends_on = [
    azurerm_role_assignment.general_storage_cmk
  ]
}

resource "azurerm_private_endpoint" "fslogix_file" {
  provider            = azurerm.spoke
  name                = var.fslogix_file_private_endpoint_name
  resource_group_name = var.rg_storage_name
  location            = var.avdLocation
  subnet_id           = "/subscriptions/${var.spoke_subscription_id}/resourceGroups/${var.rg_network}/providers/Microsoft.Network/virtualNetworks/${var.vnet_name}/subnets/${var.pesubnet_files}"
  tags                = var.tags

  private_service_connection {
    name                           = var.fslogix_file_private_service_connection_name
    private_connection_resource_id = azapi_resource.fslogix_storage.id
    is_manual_connection           = false
    subresource_names              = ["file"]
  }

  private_dns_zone_group {
    name                 = var.fslogix_file_private_dns_zone_group_name
    private_dns_zone_ids = [data.azurerm_private_dns_zone.file_dns.id]
  }
}

resource "azurerm_private_endpoint" "general_blob" {
  provider            = azurerm.spoke
  name                = var.general_blob_private_endpoint_name
  resource_group_name = var.rg_storage_name
  location            = var.avdLocation
  subnet_id           = "/subscriptions/${var.spoke_subscription_id}/resourceGroups/${var.rg_network}/providers/Microsoft.Network/virtualNetworks/${var.vnet_name}/subnets/${var.pesubnet_files}"
  tags                = var.tags

  private_service_connection {
    name                           = var.general_blob_private_service_connection_name
    private_connection_resource_id = azapi_resource.general_storage.id
    is_manual_connection           = false
    subresource_names              = ["blob"]
  }

  private_dns_zone_group {
    name                 = var.general_blob_private_dns_zone_group_name
    private_dns_zone_ids = [data.azurerm_private_dns_zone.blob_dns.id]
  }
}

# Network rules are applied after private endpoints exist so the private path is
# available before default public network access is denied.
resource "azurerm_storage_account_network_rules" "fslogix" {
  provider           = azurerm.spoke
  storage_account_id = azapi_resource.fslogix_storage.id
  default_action     = "Deny"
  bypass             = ["AzureServices"]

  depends_on = [
    azurerm_private_endpoint.fslogix_file
  ]
}

resource "azurerm_storage_account_network_rules" "general" {
  provider           = azurerm.spoke
  storage_account_id = azapi_resource.general_storage.id
  default_action     = "Deny"
  bypass             = ["AzureServices"]

  depends_on = [
    azurerm_private_endpoint.general_blob
  ]
}

# Grant SMB data-plane access to the group that will store FSLogix profiles.
resource "azurerm_role_assignment" "fslogix_users" {
  provider             = azurerm.spoke
  scope                = azapi_resource.fslogix_share.id
  role_definition_name = "Storage File Data SMB Share Contributor"
  principal_id         = data.azuread_group.fslogix_users.object_id
}
