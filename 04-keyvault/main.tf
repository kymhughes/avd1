# ── Key Vault — CMK Key, VM Password Secret, Private Endpoint ─────────────────
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


# ── Private DNS Zone for Key Vault (pre-existing in hub) ─────────────────────
data "azurerm_private_dns_zone" "kv_dns" {
  provider            = azurerm.hub
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = var.hub_dns_zone_rg
}

# ── Key Vault (AVM v0.10.2) ────────────────────────────────────────────────────
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
  enable_telemetry              = var.enable_telemetry
  public_network_access_enabled = false
  purge_protection_enabled      = false
  #soft_delete_retention_days    = 90

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

  # NOTE: CMK key creation requires data-plane access to the Key Vault.
  # Azure Policy in this environment enforces publicNetworkAccess=Disabled, so
  # the key must be created from within the spoke VNet (e.g. a self-hosted runner
  # or jump box). Uncomment and run from within the network:
  # keys = {
  #   cmk = {
  #     name     = "avd-cmk-key"
  #     key_type = "RSA"
  #     key_size = 4096
  #     key_opts = ["decrypt", "encrypt", "sign", "unwrapKey", "verify", "wrapKey"]
  #   }
  # }

  # wait_for_rbac_before_key_operations = {
  #   create = "10s"
  # }
}

resource "time_sleep" "wait_for_keyvault_private_endpoint" {
  create_duration = "120s"

  depends_on = [
    module.avm_res_keyvault_vault
  ]
}

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
