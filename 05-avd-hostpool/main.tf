# ── AVD Host Pool, Application Group, Workspace, Scaling Plan ─────────────────
# Depends on: 01-resource-groups (rg_service_objects_name), 03-monitoring (log_analytics_workspace_id)
# Provides:   hostpool_id, registration_token, application_group_id, workspace_id
#             → consumed by 07-session-hosts, 08-rbac
#
# CRITICAL: Entra SSO properties (enablerdsaadauth, targetisaadjoined) MUST be in
#           custom_properties{} map — NOT in custom_rdp_properties typed object.
#           The AVM typed object only supports 11 named fields and silently drops anything else.

resource "azurerm_resource_group" "service_objects" {
  location = var.avdLocation
  name     = var.rg_so
  tags     = var.tags
  lifecycle { prevent_destroy = false }
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

  # depends_on = [azurerm_resource_group.]
}


# # ── Host Pool (AVM v0.4.0) ────────────────────────────────────────────────────
# module "avm_res_desktopvirtualization_hostpool" {
#   source  = "Azure/avm-res-desktopvirtualization-hostpool/azurerm"
#   version = "0.4.0"

#   virtual_desktop_host_pool_name                = var.hostpool_name
#   virtual_desktop_host_pool_resource_group_name = var.rg_pool
#   resource_group_name                           = var.rg_so
#   virtual_desktop_host_pool_location            = var.avdLocation
#   virtual_desktop_host_pool_tags                = var.tags
#   enable_telemetry                              = var.enable_telemetry
#   virtual_desktop_host_pool_type                     = "Pooled"
#   virtual_desktop_host_pool_load_balancer_type       = "BreadthFirst"
#   virtual_desktop_host_pool_maximum_sessions_allowed = 2
#   virtual_desktop_host_pool_start_vm_on_connect      = true
#   virtual_desktop_host_pool_validate_environment     = false

#   # custom_rdp_properties is an object with 11 named fields + custom_properties map.
#   # Non-standard RDP flags (audiocapturemode, screen mode id, Entra SSO) go in custom_properties.
#   virtual_desktop_host_pool_custom_rdp_properties = {
#     audiomode          = 0
#     redirectclipboard  = 1
#     redirectcomports   = 0
#     redirectprinters   = 1
#     redirectsmartcards = 1
#     custom_properties = {
#       "audiocapturemode"  = "i:1"
#       "screen mode id"    = "i:2"
#       "enablerdsaadauth"  = "i:1"
#       "targetisaadjoined" = "i:1"
#     }
#   }

# registration_expiration_period accepts a duration string (e.g. "2h", "48h", max "720h"/30d)
# registration_expiration_period = "720h"

# diagnostic_settings = {
#   diag = {
#     workspace_resource_id = var.log_analytics_workspace_id
#     log_categories        = var.host_pool_log_categories
#     log_groups            = []
#   }
# }
# }

# ── Application Group (AVM v0.2.1) ────────────────────────────────────────────
module "avm_res_desktopvirtualization_applicationgroup" {
  source  = "Azure/avm-res-desktopvirtualization-applicationgroup/azurerm"
  version = "0.2.1"

  virtual_desktop_application_group_name                = var.app_group_name
  virtual_desktop_application_group_resource_group_name = var.rg_so
  virtual_desktop_application_group_location            = var.avdLocation
  virtual_desktop_application_group_tags                = var.tags
  enable_telemetry                                      = var.enable_telemetry
  virtual_desktop_application_group_type                = var.app_group_type
  #virtual_desktop_application_group_host_pool_id                 = module.avm_res_desktopvirtualization_hostpool.resource_id 
  virtual_desktop_application_group_host_pool_id                 = azurerm_virtual_desktop_host_pool.this.id
  virtual_desktop_application_group_default_desktop_display_name = var.app_group_default_desktop_display_name

  role_assignments = {
    avd_users = {
      role_definition_id_or_name = "Desktop Virtualization User"
      principal_id               = data.azuread_group.avd_users.object_id
    }
  }

  # diagnostic_settings = {
  #   diag = {
  #     workspace_resource_id = var.log_analytics_workspace_id
  #     log_categories        = var.dag_log_categories
  #     log_groups            = []
  #   }
  # }
}

# ── Workspace (AVM v0.2.2) ────────────────────────────────────────────────────
module "avm_res_desktopvirtualization_workspace" {
  source  = "Azure/avm-res-desktopvirtualization-workspace/azurerm"
  version = "0.2.2"

  virtual_desktop_workspace_name                = var.workspace_name
  virtual_desktop_workspace_resource_group_name = azurerm_resource_group.service_objects.name
  virtual_desktop_workspace_location            = var.avdLocation
  virtual_desktop_workspace_tags                = var.tags
  enable_telemetry                              = var.enable_telemetry

  # Disable public access — clients must use the workspace feed private endpoint.
  public_network_access_enabled = false

  # diagnostic_settings = {
  #   diag = {
  #     workspace_resource_id = var.log_analytics_workspace_id
  #     log_categories        = var.ws_log_categories
  #     log_groups            = []
  #   }
  # }
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

# # workspace v0.2.2 has no application_group_ids input; association is a separate resource
# resource "azurerm_virtual_desktop_workspace_application_group_association" "this" {
#   workspace_id         = module.avm_res_desktopvirtualization_workspace.resource.id
#   application_group_id = module.avm_res_desktopvirtualization_applicationgroup.resource_id
# }

# ── Scaling Plan (AVM v0.2.1) ─────────────────────────────────────────────────
module "avm_res_desktopvirtualization_scaling_plan" {
  source  = "Azure/avm-res-desktopvirtualization-scalingplan/azurerm"
  version = "0.2.1"

  depends_on = [azurerm_role_assignment.scaling_plan_sp]

  virtual_desktop_scaling_plan_name                = var.scplan_name
  virtual_desktop_scaling_plan_resource_group_name = var.rg_so
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

# # ── Diagnostic Storage Account (for host pool diagnostics) ───────────────────
# resource "azurerm_storage_account" "diagnostics" {
#   name                            = lower(replace("stavddiag${var.prefix}${random_string.suffix.id}", "-", ""))
#   resource_group_name             = var.rg_so
#   location                        = var.avdLocation
#   account_tier                    = "Standard"
#   account_replication_type        = "LRS"
#   shared_access_key_enabled       = false
#   public_network_access_enabled   = false
#   min_tls_version                 = "TLS1_2"
#   tags                            = var.tags
#   lifecycle { prevent_destroy = false }
# }

# ── Private DNS Zone for AVD Workspace feed (pre-existing in hub) ────────────
# Prerequisite: "privatelink.wvd.microsoft.com" zone must already exist in
# var.hub_dns_zone_rg before running this module.
data "azurerm_private_dns_zone" "avd_feed_dns" {
  provider            = azurerm.hub
  name                = "privatelink.wvd.microsoft.com"
  resource_group_name = var.hub_dns_zone_rg
}

# # VNet link — connects spoke VNet to the hub AVD DNS zone so clients
# # resolve the workspace feed URL over the private network.
# resource "azurerm_private_dns_zone_virtual_network_link" "avd_feed_dns_link" {
#   provider              = azurerm.hub
#   name                  = "link-avd-ws-${var.prefix}-${var.app_name}"
#   resource_group_name   = var.hub_dns_zone_rg
#   private_dns_zone_name = data.azurerm_private_dns_zone.avd_feed_dns.name
#   virtual_network_id    = var.spoke_vnet_id
#   registration_enabled  = false
#   tags                  = var.tags
#   lifecycle { prevent_destroy = false }
# }

# ── Private DNS Zone for AVD global feed (pre-existing in hub) ─────────────
# Prerequisite: "privatelink-global.wvd.microsoft.com" zone must already exist.
# Used by the workspace global private endpoint (initial feed discovery URL).
data "azurerm_private_dns_zone" "avd_global_dns" {
  provider            = azurerm.hub
  name                = "privatelink-global.wvd.microsoft.com"
  resource_group_name = var.hub_dns_zone_rg
}

# resource "azurerm_private_dns_zone_virtual_network_link" "avd_global_dns_link" {
#   provider              = azurerm.hub
#   name                  = "link-avd-global-${var.prefix}-${var.app_name}"
#   resource_group_name   = var.hub_dns_zone_rg
#   private_dns_zone_name = data.azurerm_private_dns_zone.avd_global_dns.name
#   virtual_network_id    = var.spoke_vnet_id
#   registration_enabled  = false
#   tags                  = var.tags
#   lifecycle { prevent_destroy = false }
# }

# ── Workspace Private Endpoint (feed) ───────────────────────────────────
# Enables clients to resolve the AVD workspace feed URL over the private network.
# One PE per app_name deployment — each host pool / workspace gets its own PE.
resource "azurerm_private_endpoint" "workspace_pe" {
  name                = "pe-avd-ws-${var.prefix}"
  resource_group_name = var.rg_so
  location            = var.avdLocation
  #subnet_id           = var.pesubnet_id
  subnet_id = "/subscriptions/${var.spoke_subscription_id}/resourceGroups/${var.rg_network}/providers/Microsoft.Network/virtualNetworks/${var.vnet_name}/subnets/${var.pesubnet_workspace}"
  tags      = var.tags

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

# ── Workspace Private Endpoint (global) ────────────────────────────────
# Required for AVD clients to resolve the initial (global) workspace URL
# before being redirected to the per-tenant feed endpoint.
resource "azurerm_private_endpoint" "workspace_global_pe" {
  name                = "pe-avd-ws-global-${var.prefix}"
  resource_group_name = var.rg_so
  location            = var.avdLocation
  #subnet_id          = var.pesubnet_id
  subnet_id = "/subscriptions/${var.spoke_subscription_id}/resourceGroups/${var.rg_network}/providers/Microsoft.Network/virtualNetworks/${var.vnet_name}/subnets/${var.pesubnet_avdglobal}"
  tags      = var.tags

  private_service_connection {
    name                           = "psc-ws-global-${var.prefix}"
    private_connection_resource_id = module.avm_res_desktopvirtualization_workspace.resource.id
    is_manual_connection           = false
    subresource_names              = ["global"]
  }

  private_dns_zone_group {
    name                 = "dns-ws-global-${var.prefix}"
    private_dns_zone_ids = [data.azurerm_private_dns_zone.avd_global_dns.id]
  }

  depends_on = [module.avm_res_desktopvirtualization_workspace]
  lifecycle { prevent_destroy = false }
}

# ── Host Pool Private Endpoint (connection) ──────────────────────────────
# Enables session hosts to register with the host pool control plane
# over the private network instead of the public internet.
# Uses the same privatelink.wvd.microsoft.com zone as the workspace feed PE.
resource "azurerm_private_endpoint" "hostpool_pe" {
  name                = "pe-avd-hp-${var.prefix}"
  resource_group_name = azurerm_resource_group.service_objects.name
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

  #depends_on = [module.avm_res_desktopvirtualization_hostpool]
  depends_on = [azurerm_virtual_desktop_host_pool.this]
  lifecycle { prevent_destroy = false }
}


