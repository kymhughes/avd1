# Creates the private Key Vault used by AVD session host automation.
# The module stores generated local administrator credentials as secrets and
# grants the AVD service principal read access through Key Vault RBAC.
# resource "azurerm_resource_group" "service_objects" {
#   location = var.avdLocation
#   name     = var.rg_so
#   tags     = var.tags
#   lifecycle { prevent_destroy = false }
# }

data "azurerm_resource_group" "service_objects" {
  name = var.rg_so
}

data "azurerm_client_config" "current" {}

resource "random_password" "local" {
  length           = 24
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}


# The Key Vault private DNS zone is centralised in the hub subscription.
data "azurerm_private_dns_zone" "kv_dns" {
  provider            = azurerm.hub
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = var.hub_dns_zone_rg
}

# Public network access is disabled, so any data-plane operations after creation
# depend on private endpoint DNS and routing from the Terraform runner.
module "avm_res_keyvault_vault" {
  source = "Azure/avm-res-keyvault-vault/azurerm"
  #version   = "0.5.3"
  #version   = "0.10.2"
  version = "0.11.0"

  providers = { azurerm = azurerm.spoke }

  name                          = var.keyvault_name
  location                      = var.avdLocation
  resource_group_name           = data.azurerm_resource_group.service_objects.name
  tenant_id                     = var.tenant_id
  tags                          = var.tags
  enable_telemetry              = false
  public_network_access_enabled = false
  purge_protection_enabled      = var.purge_protection_enabled
  soft_delete_retention_days    = var.soft_delete_retention_days

  network_acls = {
    #bypass         = "None"
    bypass         = "AzureServices"
    default_action = "Deny"
  }

  private_endpoints = {
    vault = {
      name                            = var.keyvault_pe_name
      subnet_resource_id              = "/subscriptions/${var.spoke_subscription_id}/resourceGroups/${var.rg_network}/providers/Microsoft.Network/virtualNetworks/${var.vnet_name}/subnets/${var.pesubnet_keyvault}"
      private_dns_zone_group_name     = "default"
      private_dns_zone_resource_ids   = [data.azurerm_private_dns_zone.kv_dns.id]
      private_service_connection_name = var.keyvault_sc_name
      location                        = var.avdLocation
      resource_group_name             = data.azurerm_resource_group.service_objects.name
    }
  }

  role_assignments = {
    kv_admin = {
      role_definition_id_or_name = "Key Vault Administrator"
      principal_id               = data.azurerm_client_config.current.object_id
    }
  }

  # wait_for_rbac_before_key_operations = {
  #   create = "10s"
  # }
}

# Give private endpoint DNS and routing time to settle before writing secrets.
resource "time_sleep" "wait_for_keyvault_private_endpoint" {
  create_duration = "120s"

  depends_on = [
    module.avm_res_keyvault_vault
  ]
}

# The CMK is created after the private endpoint is available because Key Vault
# key operations are data-plane calls and public network access is disabled.
resource "azurerm_key_vault_key" "cmk" {
  provider = azurerm.spoke

  name         = var.cmk_key_name
  key_vault_id = module.avm_res_keyvault_vault.resource_id
  key_type     = "RSA"
  key_size     = var.cmk_key_size
  key_opts     = ["decrypt", "encrypt", "sign", "unwrapKey", "verify", "wrapKey"]
  tags         = var.tags

  rotation_policy {
    automatic {
      time_after_creation = var.cmk_key_rotation_time_after_creation
    }

    expire_after         = var.cmk_key_expire_after
    notify_before_expiry = var.cmk_key_notify_before_expiry
  }

  depends_on = [
    time_sleep.wait_for_keyvault_private_endpoint
  ]
}

resource "azurerm_user_assigned_identity" "disk_encryption_set" {
  provider = azurerm.spoke

  name                = var.disk_encryption_set_identity_name
  location            = var.avdLocation
  resource_group_name = data.azurerm_resource_group.service_objects.name
  tags                = var.tags
}

resource "azurerm_role_assignment" "disk_encryption_set_key_access" {
  provider = azurerm.spoke

  scope                = module.avm_res_keyvault_vault.resource_id
  role_definition_name = "Key Vault Crypto Service Encryption User"
  principal_id         = azurerm_user_assigned_identity.disk_encryption_set.principal_id
}

resource "azurerm_disk_encryption_set" "avd" {
  provider = azurerm.spoke

  name                      = var.disk_encryption_set_name
  location                  = var.avdLocation
  resource_group_name       = data.azurerm_resource_group.service_objects.name
  key_vault_key_id          = azurerm_key_vault_key.cmk.versionless_id
  auto_key_rotation_enabled = true
  encryption_type           = "EncryptionAtRestWithCustomerKey"
  tags                      = var.tags

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.disk_encryption_set.id]
  }

  depends_on = [
    azurerm_role_assignment.disk_encryption_set_key_access
  ]
}

# Host pool automation reads these secrets when creating managed session hosts.
resource "azurerm_role_assignment" "avd_keyvault_secrets_user" {
  provider = azurerm.spoke

  scope                            = module.avm_res_keyvault_vault.resource_id
  role_definition_name             = "Key Vault Secrets User"
  principal_id                     = var.avd_service_principal_object_id
  skip_service_principal_aad_check = true

  depends_on = [
    module.avm_res_keyvault_vault
  ]
}

resource "azurerm_key_vault_secret" "vm_local_admin_username" {
  provider = azurerm.spoke

  name         = var.vm_local_admin_username_secret_name
  value        = var.vm_local_admin_username
  key_vault_id = module.avm_res_keyvault_vault.resource_id
  content_type = "AVD session host local administrator username"
  tags         = var.tags

  # Secret values are intentionally managed as create-time values. This avoids
  # accidental credential rotation on routine Terraform runs.
  lifecycle {
    ignore_changes = [
      value,
      tags
    ]
  }

  depends_on = [
    time_sleep.wait_for_keyvault_private_endpoint
  ]
}

resource "azurerm_key_vault_secret" "vm_local_admin_password" {
  provider = azurerm.spoke

  name         = var.vm_local_admin_password_secret_name
  value        = random_password.local.result
  key_vault_id = module.avm_res_keyvault_vault.resource_id
  content_type = "AVD session host local administrator password"
  tags         = var.tags

  # Secret values are intentionally managed as create-time values. This avoids
  # accidental credential rotation on routine Terraform runs.
  lifecycle {
    ignore_changes = [
      value,
      tags
    ]
  }

  depends_on = [
    time_sleep.wait_for_keyvault_private_endpoint
  ]
}
