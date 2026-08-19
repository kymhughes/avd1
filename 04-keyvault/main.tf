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
  rbac_authorization_enabled = true

  network_acls = {
    bypass         = "None"
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

  # secrets = {
  #   local_password = {
  #     name = "vm-local-admin-password"
  #   }
  # }

  secrets_value = {
    local_password = random_password.local.result
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


# # ── VM Local Admin Password Secret ───────────────────────────────────────────
# resource "azurerm_key_vault_secret" "localpassword" {
#   provider     = azurerm.spoke
#   name         = "avd-local-admin-password"
#   value        = random_password.vmpass.result
#   key_vault_id = module.avm_res_keyvault_vault.keyvault_id
#   content_type = "AVD Local Admin Password"
#   #tags         = var.tags
#   lifecycle { ignore_changes = [tags] }
#   depends_on = [module.avm_res_keyvault_vault]
# }

# resource "random_password" "vmpass" {
#   length      = 20
#   special     = true
#   min_lower   = 2
#   min_upper   = 2
#   min_numeric = 2
#   min_special = 2
# }
