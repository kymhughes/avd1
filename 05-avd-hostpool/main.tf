# ── AVD Host Pool, Application Group, Workspace, Scaling Plan ─────────────────
# Depends on: 01-resource-groups (rg_service_objects_name), 03-monitoring (log_analytics_workspace_id)
# Provides:   hostpool_id, registration_token, application_group_id, workspace_id
#             → consumed by 07-session-hosts, 08-rbac
#
# CRITICAL: Entra SSO properties (enablerdsaadauth, targetisaadjoined) MUST be in
#           custom_properties{} map — NOT in custom_rdp_properties typed object.
#           The AVM typed object only supports 11 named fields and silently drops anything else.

data "azurerm_resource_group" "service_objects" {
  name = var.rg_so
}

resource "azurerm_resource_group" "compute" {
  location = var.avdLocation
  name     = var.rg_pool
  tags     = var.tags
  lifecycle { prevent_destroy = false }
}

data "azurerm_client_config" "current" {}

data "azuread_group" "avd_users" {
  display_name     = var.user_group_name
  security_enabled = true
}

resource "random_string" "suffix" {
  length  = 4
  special = false
  upper   = false
}

# # ── Host Pool (AzureRM) ───────────────
# AVD current version (v0.4.0 ) does not support disabling public access as part of deployment, so 
# reverting to Azurerm in the short term.  once AVM (likely v0.5.0+) supports this feature, then this code sholud be reverted to AVM code below
resource "azurerm_virtual_desktop_host_pool" "this" {
  name                = var.hostpool_name
  location            = var.avdLocation
  resource_group_name = azurerm_resource_group.compute.name

  public_network_access    = "Disabled"
  type                     = var.hostpool_type
  load_balancer_type       = var.hostpool_load_balancer_type
  maximum_sessions_allowed = var.hostpool_maximum_sessions_allowed
  start_vm_on_connect      = var.hostpool_start_vm_on_connect
  validate_environment     = var.hostpool_validate_environment
  custom_rdp_properties    = var.hostpool_custom_rdp_properties
  tags                     = var.tags
}



# ── Application Group (AVM v0.2.1) ────────────────────────────────────────────
module "avm_res_desktopvirtualization_applicationgroup" {
  source  = "Azure/avm-res-desktopvirtualization-applicationgroup/azurerm"
  version = "0.2.1"

  virtual_desktop_application_group_name                         = var.app_group_name
  virtual_desktop_application_group_resource_group_name          = azurerm_resource_group.compute.name
  virtual_desktop_application_group_location                     = var.avdLocation
  virtual_desktop_application_group_tags                         = var.tags
  enable_telemetry                                               = var.enable_telemetry
  virtual_desktop_application_group_type                         = var.app_group_type
  virtual_desktop_application_group_host_pool_id                 = azurerm_virtual_desktop_host_pool.this.id
  virtual_desktop_application_group_default_desktop_display_name = var.app_group_default_desktop_display_name

  role_assignments = {
    avd_users = {
      role_definition_id_or_name = "Desktop Virtualization User"
      principal_id               = data.azuread_group.avd_users.object_id
    }
  }
}

# ── Workspace (AVM v0.2.2) ────────────────────────────────────────────────────
module "avm_res_desktopvirtualization_workspace" {
  source  = "Azure/avm-res-desktopvirtualization-workspace/azurerm"
  version = "0.2.2"

  virtual_desktop_workspace_name                = var.workspace_name
  virtual_desktop_workspace_resource_group_name = data.azurerm_resource_group.service_objects.name
  virtual_desktop_workspace_location            = var.avdLocation
  virtual_desktop_workspace_tags                = var.tags
  enable_telemetry                              = var.enable_telemetry
  public_network_access_enabled                 = false
}

# ── Workspace ↔ Application Group association ─────────────────────────────────
# The AVD service principal needs 'Desktop Virtualization Power On Off Contributor' on the host pool
# before a scaling plan can be attached. The role_assignments variable in hostpool AVM v0.4.0 is
# declared but unimplemented, so we use a standalone resource with explicit ordering.
resource "azurerm_role_assignment" "scaling_plan_sp" {
  #scope                            = module.avm_res_desktopvirtualization_hostpool.resource_id
  scope                            = azurerm_virtual_desktop_host_pool.this.id
  role_definition_name             = "Desktop Virtualization Power On Off Contributor"
  principal_id                     = var.scaling_plan_sp_id
  skip_service_principal_aad_check = true
}

# ── Scaling Plan (AVM v0.2.1) ─────────────────────────────────────────────────
module "avm_res_desktopvirtualization_scaling_plan" {
  source  = "Azure/avm-res-desktopvirtualization-scalingplan/azurerm"
  version = "0.2.1"

  depends_on = [azurerm_role_assignment.scaling_plan_sp]

  virtual_desktop_scaling_plan_name                = var.scplan_name
  virtual_desktop_scaling_plan_resource_group_name = var.rg_pool
  virtual_desktop_scaling_plan_location            = var.avdLocation
  virtual_desktop_scaling_plan_tags                = var.tags
  enable_telemetry                                 = var.enable_telemetry

  virtual_desktop_scaling_plan_time_zone = "AUS Eastern Standard Time"
  virtual_desktop_scaling_plan_host_pool = [
    {
      #hostpool_id          = module.avm_res_desktopvirtualization_hostpool.resource_id
      hostpool_id          = azurerm_virtual_desktop_host_pool.this.id
      scaling_plan_enabled = true
    }
  ]

  virtual_desktop_scaling_plan_schedule = [
    {
      name                                 = "Weekdays"
      days_of_week                         = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]
      off_peak_start_time                  = "19:00"
      off_peak_load_balancing_algorithm    = "DepthFirst"
      ramp_down_start_time                 = "18:00"
      ramp_down_load_balancing_algorithm   = "DepthFirst"
      ramp_down_minimum_hosts_percent      = 10
      ramp_down_force_logoff_users         = false
      ramp_down_wait_time_minutes          = 45
      ramp_down_notification_message       = "Please save your work. Session will be disconnected in 15 minutes."
      ramp_down_capacity_threshold_percent = 90
      ramp_down_stop_hosts_when            = "ZeroActiveSessions"
      ramp_up_load_balancing_algorithm     = "BreadthFirst"
      ramp_up_start_time                   = "07:00"
      ramp_up_capacity_threshold_percent   = 60
      ramp_up_minimum_hosts_percent        = 20
      peak_load_balancing_algorithm        = "BreadthFirst"
      peak_start_time                      = "09:00"
    }
  ]
}




# ── Private DNS Zone for AVD Workspace feed (pre-existing in hub) ────────────
data "azurerm_private_dns_zone" "avd_feed_dns" {
  provider            = azurerm.hub
  name                = "privatelink.wvd.microsoft.com"
  resource_group_name = var.hub_dns_zone_rg
}

# ── Workspace Private Endpoint (feed) ───────────────────────────────────
resource "azurerm_private_endpoint" "workspace_pe" {
  name                = "pe-avd-ws-${var.prefix}"
  resource_group_name = data.azurerm_resource_group.service_objects.name
  location            = var.avdLocation
  subnet_id           = "/subscriptions/${var.spoke_subscription_id}/resourceGroups/${var.rg_network}/providers/Microsoft.Network/virtualNetworks/${var.vnet_name}/subnets/${var.pesubnet_workspace}"
  tags                = var.tags

  private_service_connection {
    name                           = "psc-ws-${var.prefix}"
    private_connection_resource_id = module.avm_res_desktopvirtualization_workspace.resource.id
    is_manual_connection           = false
    subresource_names              = ["feed"]
  }

  private_dns_zone_group {
    name                 = "dns-ws-${var.prefix}"
    private_dns_zone_ids = [data.azurerm_private_dns_zone.avd_feed_dns.id]
  }

  depends_on = [module.avm_res_desktopvirtualization_workspace]
  lifecycle { prevent_destroy = false }
}



# ── Host Pool Private Endpoint (connection) ──────────────────────────────
resource "azurerm_private_endpoint" "hostpool_pe" {
  name                = "pe-avd-hp-${var.prefix}"
  resource_group_name = azurerm_resource_group.compute.name
  location            = var.avdLocation
  #subnet_id          = var.pesubnet_id
  subnet_id = "/subscriptions/${var.spoke_subscription_id}/resourceGroups/${var.rg_network}/providers/Microsoft.Network/virtualNetworks/${var.vnet_name}/subnets/${var.pesubnet_hostpool1}"
  tags      = var.tags

  private_service_connection {
    name = "psc-hp-${var.prefix}"
    #private_connection_resource_id = module.avm_res_desktopvirtualization_hostpool.resource_id
    private_connection_resource_id = azurerm_virtual_desktop_host_pool.this.id
    is_manual_connection           = false
    subresource_names              = ["connection"]
  }

  private_dns_zone_group {
    name                 = "dns-hp-${var.prefix}"
    private_dns_zone_ids = [data.azurerm_private_dns_zone.avd_feed_dns.id]
  }
  depends_on = [azurerm_virtual_desktop_host_pool.this]
  lifecycle { prevent_destroy = false }
}


resource "time_offset" "avd_registration_token_expiry" {
  count = var.avd_host_pool_id == null ? 0 : 1

  offset_hours = var.avd_registration_token_expiry_hours
}

resource "azurerm_virtual_desktop_host_pool_registration_info" "avd" {
  count = var.avd_host_pool_id == null ? 0 : 1

  hostpool_id     = var.avd_host_pool_id
  expiration_date = time_offset.avd_registration_token_expiry[0].rfc3339
}


resource "random_password" "local" {
  length           = var.local_password_length
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

locals {
  key_vault_secrets = merge(
    {
      local_password = {
        name = var.local_password_secret_name
      }
    },
    var.avd_host_pool_id == null ? {} : {
      avd_registration_token = {
        name            = var.avd_registration_token_secret_name
        content_type    = "AVD host pool registration token"
        expiration_date = time_offset.avd_registration_token_expiry[0].rfc3339
      }
    }
  )

  key_vault_secret_values = merge(
    {
      local_password = random_password.local.result
    },
    var.avd_host_pool_id == null ? {} : {
      avd_registration_token = azurerm_virtual_desktop_host_pool_registration_info.avd[0].token
    }
  )
}

# resource "time_sleep" "wait_for_private_link" {
#   create_duration = var.private_link_secret_wait_duration

#   depends_on = [
#     module.key_vault,
#     azurerm_private_dns_zone_virtual_network_link.key_vault
#   ]
# }

data "avm_res_keyvault_vault" "key_vault" {
  name                = var.keyvault_name
  resource_group_name = azurerm_resource_group.service_objects.name
}

resource "azurerm_key_vault_secret" "this" {
  for_each = local.key_vault_secrets

  name            = each.value.name
  value           = local.key_vault_secret_values[each.key]
  key_vault_id    = data.avm_res_keyvault_vault.key_vault.id
  content_type    = try(each.value.content_type, null)
  expiration_date = try(each.value.expiration_date, null)

  # depends_on = [time_sleep.wait_for_private_link]
}





# # ── Private DNS Zone for AVD global feed (pre-existing in hub) ─────────────
# # Prerequisite: "privatelink-global.wvd.microsoft.com" zone must already exist.
# # Used by the workspace global private endpoint (initial feed discovery URL).
# data "azurerm_private_dns_zone" "avd_global_dns" {
#   provider            = azurerm.hub
#   name                = "privatelink-global.wvd.microsoft.com"
#   resource_group_name = var.hub_dns_zone_rg
# }

# # ── Workspace Private Endpoint (global) ────────────────────────────────
# # Required for AVD clients to resolve the initial (global) workspace URL
# # before being redirected to the per-tenant feed endpoint.
# resource "azurerm_private_endpoint" "workspace_global_pe" {
#   name                = "pe-avd-ws-global-${var.prefix}"
#   resource_group_name = var.rg_so
#   location            = var.avdLocation
#   #subnet_id          = var.pesubnet_id
#   subnet_id = "/subscriptions/${var.spoke_subscription_id}/resourceGroups/${var.rg_network}/providers/Microsoft.Network/virtualNetworks/${var.vnet_name}/subnets/${var.pesubnet_avdglobal}"
#   tags      = var.tags

#   private_service_connection {
#     name                           = "psc-ws-global-${var.prefix}"
#     private_connection_resource_id = module.avm_res_desktopvirtualization_workspace.resource.id
#     is_manual_connection           = false
#     subresource_names              = ["global"]
#   }

#   private_dns_zone_group {
#     name                 = "dns-ws-global-${var.prefix}"
#     private_dns_zone_ids = [data.azurerm_private_dns_zone.avd_global_dns.id]
#   }

#   depends_on = [module.avm_res_desktopvirtualization_workspace]
#   lifecycle { prevent_destroy = false }
# }