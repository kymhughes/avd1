# ── AVD Host Pool, Application Group, Workspace, Scaling Plan ─────────────────
# Depends on: 01-resource-groups (rg_service_objects_name), 03-monitoring (log_analytics_workspace_id)
# Provides:   hostpool_id, registration_token, application_group_id, workspace_id
#             → consumed by 07-session-hosts, 08-rbac
#
# CRITICAL: Entra SSO properties (enablerdsaadauth, targetisaadjoined) MUST be in
#           custom_properties{} map — NOT in custom_rdp_properties typed object.
#           The AVM typed object only supports 11 named fields and silently drops anything else.


# Commended out temporarily due to missing Entra ID access
# data "azuread_group" "avd_users" {
#   display_name     = var.user_group_name
#   security_enabled = true
# }


data "azurerm_resource_group" "service_objects" {
  name = var.rg_so
}

data "azurerm_virtual_desktop_workspace" "this" {
  name                = var.workspace_name
  resource_group_name = coalesce(var.workspace_resource_group_name, var.rg_so)
}

data "azurerm_key_vault" "session_host_secrets" {
  name                = var.key_vault_name
  resource_group_name = var.rg_so
}

data "azurerm_client_config" "current" {}




# this is redundant when VM Contributor is used.
# resource "azurerm_role_assignment" "avd_power_on_off" {
#   scope                            = "/subscriptions/${var.spoke_subscription_id}"
#   role_definition_name             = "Desktop Virtualization Power On Off Contributor"
#   principal_id                     = var.avd_service_principal_object_id
#   skip_service_principal_aad_check = true
# }

###################################################################################
#Assign nesssesary roles to the AVD service principal for dynamic autoscale to work
###################################################################################
resource "azurerm_role_assignment" "avd_reader" {
  scope                            = "/subscriptions/${var.spoke_subscription_id}"
  role_definition_name             = "Reader"
  principal_id                     = var.avd_service_principal_object_id
  skip_service_principal_aad_check = true
}
# VM Contributor role so it can start/stop/create/delete VMs for dynamic autoscale
resource "azurerm_role_assignment" "avd_vm_on_off_contributor" {
  scope                            = "/subscriptions/${var.spoke_subscription_id}"
  role_definition_name             = "Desktop Virtualization Power On Off Contributor"
  principal_id                     = var.avd_service_principal_object_id
  skip_service_principal_aad_check = true
}

# VM Contributor role so it can start/stop/create/delete VMs for dynamic autoscale
resource "azurerm_role_assignment" "avd_vm_contributor" {
  scope                            = "/subscriptions/${var.spoke_subscription_id}"
  role_definition_name             = "Desktop Virtualization Virtual Machine Contributor"
  principal_id                     = var.avd_service_principal_object_id
  skip_service_principal_aad_check = true
}

# Secrets access
resource "azurerm_role_assignment" "avd_keyvault_secrets_user" {
  scope                            = data.azurerm_key_vault.session_host_secrets.id
  role_definition_name             = "Key Vault Secrets User"
  principal_id                     = var.avd_service_principal_object_id
  skip_service_principal_aad_check = true
}


###################################################################################
#Assign nesssesary roles for each Session Pool Managed ID for dynamic autoscale to work
###################################################################################

# resource group VM Contributor
resource "azurerm_role_assignment" "host_pool_mi_vm_contributor" {
  for_each = local.host_pools

  scope                = azurerm_resource_group.compute[each.key].id
  role_definition_name = "Desktop Virtualization Virtual Machine Contributor"
  principal_id         = azapi_resource.host_pool[each.key].identity[0].principal_id
}
# resource group Network Contributor
resource "azurerm_role_assignment" "host_pool_mi_network_contributor" {
  for_each = local.host_pools

  scope                = azurerm_resource_group.compute[each.key].id
  role_definition_name = "Network Contributor"
  principal_id         = azapi_resource.host_pool[each.key].identity[0].principal_id
}
#Reader
resource "azurerm_role_assignment" "host_pool_mi_subscription_reader" {
  for_each = local.host_pools

  scope                = "/subscriptions/${var.spoke_subscription_id}"
  role_definition_name = "Reader"
  principal_id         = azapi_resource.host_pool[each.key].identity[0].principal_id
}
#Assign Key Vault Secrets User role to the host pool managed identity so it can read secrets from the Key Vault
resource "azurerm_role_assignment" "host_pool_mi_keyvault_secrets_user" {
  for_each = local.host_pools

  scope                = data.azurerm_key_vault.session_host_secrets.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azapi_resource.host_pool[each.key].identity[0].principal_id
}




locals {
  host_pools = length(var.host_pools) > 0 ? {
    for host_pool in var.host_pools : host_pool.name => host_pool
    } : var.hostpool_name == null || var.app_group_name == null ? {} : {
    (var.hostpool_name) = {
      name                                   = var.hostpool_name
      resource_group_name                    = var.rg_pool
      app_group_name                         = var.app_group_name
      app_group_default_desktop_display_name = var.app_group_default_desktop_display_name
      app_group_type                         = var.app_group_type
      hostpool_type                          = var.hostpool_type
      hostpool_load_balancer_type            = var.hostpool_load_balancer_type
      hostpool_maximum_sessions_allowed      = var.hostpool_maximum_sessions_allowed
      hostpool_start_vm_on_connect           = var.hostpool_start_vm_on_connect
      hostpool_validate_environment          = var.hostpool_validate_environment
      hostpool_custom_rdp_properties         = var.hostpool_custom_rdp_properties
      session_host_configuration             = var.host_pool_vm_template
      create_registration_token              = var.create_registration_token
      registration_token_ttl                 = var.registration_token_ttl
      scaling_plan_name                      = var.scaling_plan_name
      scaling_plan_friendly_name             = var.scaling_plan_friendly_name
      scaling_plan_description               = var.scaling_plan_description
    }
  }
}

resource "azurerm_resource_group" "compute" {
  for_each = local.host_pools

  location = var.avdLocation
  name     = coalesce(each.value.resource_group_name, "rg-${each.value.name}-${var.environment}")
  tags     = var.tags
  lifecycle { prevent_destroy = false }
}

resource "azapi_resource" "host_pool" {
  for_each = local.host_pools

  type      = "Microsoft.DesktopVirtualization/hostPools@2026-04-01-preview"
  name      = each.value.name
  location  = var.avdLocation
  parent_id = azurerm_resource_group.compute[each.key].id
  tags      = var.tags

  identity {
    type = "SystemAssigned"
  }

  body = {
    properties = {
      hostPoolType          = coalesce(each.value.hostpool_type, var.hostpool_type)
      loadBalancerType      = coalesce(each.value.hostpool_load_balancer_type, var.hostpool_load_balancer_type)
      maxSessionLimit       = coalesce(each.value.hostpool_maximum_sessions_allowed, var.hostpool_maximum_sessions_allowed)
      startVMOnConnect      = coalesce(each.value.hostpool_start_vm_on_connect, var.hostpool_start_vm_on_connect)
      validationEnvironment = coalesce(each.value.hostpool_validate_environment, var.hostpool_validate_environment)
      customRdpProperty     = coalesce(each.value.hostpool_custom_rdp_properties, var.hostpool_custom_rdp_properties)
      publicNetworkAccess   = "Disabled"
      preferredAppGroupType = coalesce(each.value.app_group_type, var.app_group_type) == "Desktop" ? "Desktop" : "RailApplications"
      managementType        = "Automated"

      agentUpdate = var.scheduled_agent_updates == null ? null : {
        type                      = var.scheduled_agent_updates.enabled ? "Scheduled" : "Default"
        maintenanceWindowTimeZone = var.scheduled_agent_updates.timezone
        useSessionHostLocalTime   = var.scheduled_agent_updates.use_session_host_timezone
        maintenanceWindows = [
          for schedule in var.scheduled_agent_updates.schedules : {
            dayOfWeek = schedule.day_of_week
            hour      = schedule.hour_of_day
          }
        ]
      }
    }
  }
}

resource "azapi_resource" "session_host_configuration" {
  for_each = local.host_pools

  type      = "Microsoft.DesktopVirtualization/hostPools/sessionHostConfigurations@2026-04-01-preview"
  name      = "default"
  parent_id = azapi_resource.host_pool[each.key].id

  body = {
    properties = coalesce(each.value.session_host_configuration, var.host_pool_vm_template)
  }

  depends_on = [
    azurerm_role_assignment.avd_reader,
    azurerm_role_assignment.avd_vm_on_off_contributor,
    azurerm_role_assignment.avd_vm_contributor,
    azurerm_role_assignment.avd_keyvault_secrets_user,
    azurerm_role_assignment.host_pool_mi_network_contributor,
    azurerm_role_assignment.host_pool_mi_vm_contributor,
    azurerm_role_assignment.host_pool_mi_subscription_reader,
    azurerm_role_assignment.host_pool_mi_keyvault_secrets_user
  ]
}

resource "azapi_resource" "session_host_management" {
  for_each = local.host_pools

  type      = "Microsoft.DesktopVirtualization/hostPools/sessionHostManagements@2026-04-01-preview"
  name      = "default"
  parent_id = azapi_resource.host_pool[each.key].id

  body = {
    properties = {
      scheduledDateTimeZone          = var.scaling_plan_time_zone
      failedSessionHostCleanupPolicy = "KeepAll"

      provisioning = {
        canaryPolicy  = "Auto"
        instanceCount = 1
        setDrainMode  = false
      }

      update = {
        maxVmsRemoved      = 1
        logOffDelayMinutes = 2
        logOffMessage      = "You will be signed out while this session host is updated."
        deleteOriginalVm   = true
      }
    }
  }

  depends_on = [
    azapi_resource.session_host_configuration
  ]
}

# ── Application Groups ────────────────────────────────────────────────────────
resource "azurerm_virtual_desktop_application_group" "this" {
  for_each = local.host_pools

  name                         = each.value.app_group_name
  location                     = var.avdLocation
  resource_group_name          = azurerm_resource_group.compute[each.key].name
  type                         = coalesce(each.value.app_group_type, var.app_group_type)
  host_pool_id                 = azapi_resource.host_pool[each.key].id
  default_desktop_display_name = coalesce(each.value.app_group_default_desktop_display_name, var.app_group_default_desktop_display_name)
  tags                         = var.tags
}

resource "azurerm_role_assignment" "avd_users" {
  for_each = local.host_pools

  scope                = azurerm_virtual_desktop_application_group.this[each.key].id
  role_definition_name = "Desktop Virtualization User"
  principal_id         = coalesce(each.value.avd_users_principal_id, var.avd_users_principal_id)
}

resource "azurerm_virtual_desktop_workspace_application_group_association" "this" {
  for_each = local.host_pools

  workspace_id         = data.azurerm_virtual_desktop_workspace.this.id
  application_group_id = azurerm_virtual_desktop_application_group.this[each.key].id
}



resource "azapi_resource" "dynamic_scaling_plan" {
  for_each = var.enable_dynamic_scaling_plan ? local.host_pools : {}

  type      = "Microsoft.DesktopVirtualization/scalingPlans@2026-04-01-preview"
  name      = coalesce(each.value.scaling_plan_name, var.scaling_plan_name, "sp-${each.value.name}")
  location  = var.avdLocation
  parent_id = azurerm_resource_group.compute[each.key].id
  tags      = var.tags

  body = {
    properties = merge(
      {
        description  = coalesce(each.value.scaling_plan_description, var.scaling_plan_description)
        friendlyName = coalesce(each.value.scaling_plan_friendly_name, var.scaling_plan_friendly_name, "Dynamic Autoscale ${each.value.name}")
        hostPoolType = "Pooled"
        timeZone     = var.scaling_plan_time_zone

        hostPoolReferences = [
          {
            hostPoolArmPath    = azapi_resource.host_pool[each.key].id
            scalingPlanEnabled = true
          }
        ]

        schedules = var.dynamic_scaling_plan_schedules
      },
      var.scaling_plan_exclusion_tag == null ? {} : {
        exclusionTag = var.scaling_plan_exclusion_tag
      }
    )
  }

  lifecycle {
    ignore_changes = [body]
  }

  depends_on = [
    azurerm_role_assignment.avd_reader,
    azurerm_role_assignment.avd_vm_on_off_contributor,
    azurerm_role_assignment.avd_vm_contributor,
    azurerm_role_assignment.avd_keyvault_secrets_user,
    azurerm_role_assignment.host_pool_mi_network_contributor,
    azurerm_role_assignment.host_pool_mi_vm_contributor,
    azurerm_role_assignment.host_pool_mi_subscription_reader,
    azurerm_role_assignment.host_pool_mi_keyvault_secrets_user
  ]
}

# # ── Scaling Plan (AVM v0.2.1) ─────────────────────────────────────────────────
# module "avm_res_desktopvirtualization_scaling_plan" {
#   source  = "Azure/avm-res-desktopvirtualization-scalingplan/azurerm"
#   version = "0.2.1"

#   depends_on = [azurerm_role_assignment.scaling_plan_sp]

#   virtual_desktop_scaling_plan_name                = var.scplan_name
#   virtual_desktop_scaling_plan_resource_group_name = var.rg_pool
#   virtual_desktop_scaling_plan_location            = var.avdLocation
#   virtual_desktop_scaling_plan_tags                = var.tags
#   enable_telemetry                                 = var.enable_telemetry

#   virtual_desktop_scaling_plan_time_zone = "AUS Eastern Standard Time"
#   virtual_desktop_scaling_plan_host_pool = [
#     {
#       #hostpool_id          = module.avm_res_desktopvirtualization_hostpool.resource_id
#       hostpool_id          = azurerm_virtual_desktop_host_pool.this.id
#       scaling_plan_enabled = true
#     }
#   ]

#   virtual_desktop_scaling_plan_schedule = [
#     {
#       name                                 = "Weekdays"
#       days_of_week                         = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]
#       off_peak_start_time                  = "19:00"
#       off_peak_load_balancing_algorithm    = "DepthFirst"
#       ramp_down_start_time                 = "18:00"
#       ramp_down_load_balancing_algorithm   = "DepthFirst"
#       ramp_down_minimum_hosts_percent      = 10
#       ramp_down_force_logoff_users         = false
#       ramp_down_wait_time_minutes          = 45
#       ramp_down_notification_message       = "Please save your work. Session will be disconnected in 15 minutes."
#       ramp_down_capacity_threshold_percent = 90
#       ramp_down_stop_hosts_when            = "ZeroActiveSessions"
#       ramp_up_load_balancing_algorithm     = "BreadthFirst"
#       ramp_up_start_time                   = "07:00"
#       ramp_up_capacity_threshold_percent   = 60
#       ramp_up_minimum_hosts_percent        = 20
#       peak_load_balancing_algorithm        = "BreadthFirst"
#       peak_start_time                      = "09:00"
#     }
#   ]
# }




# # ── Private DNS Zone for AVD Workspace feed (pre-existing in hub) ────────────
# data "azurerm_private_dns_zone" "avd_feed_dns" {
#   provider            = azurerm.hub
#   name                = "privatelink.wvd.microsoft.com"
#   resource_group_name = var.hub_dns_zone_rg
# }

# # ── Workspace Private Endpoint (feed) ───────────────────────────────────
# resource "azurerm_private_endpoint" "workspace_pe" {
#   name                = "pe-avd-ws-${var.prefix}"
#   resource_group_name = data.azurerm_resource_group.service_objects.name
#   location            = var.avdLocation
#   subnet_id           = "/subscriptions/${var.spoke_subscription_id}/resourceGroups/${var.rg_network}/providers/Microsoft.Network/virtualNetworks/${var.vnet_name}/subnets/${var.pesubnet_workspace}"
#   tags                = var.tags

#   private_service_connection {
#     name                           = "psc-ws-${var.prefix}"
#     private_connection_resource_id = module.avm_res_desktopvirtualization_workspace.resource.id
#     is_manual_connection           = false
#     subresource_names              = ["feed"]
#   }

#   private_dns_zone_group {
#     name                 = "dns-ws-${var.prefix}"
#     private_dns_zone_ids = [data.azurerm_private_dns_zone.avd_feed_dns.id]
#   }

#   depends_on = [module.avm_res_desktopvirtualization_workspace]
#   lifecycle { prevent_destroy = false }
# }



# # ── Host Pool Private Endpoint (connection) ──────────────────────────────
# resource "azurerm_private_endpoint" "hostpool_pe" {
#   name                = "pe-avd-hp-${var.prefix}"
#   resource_group_name = azurerm_resource_group.compute.name
#   location            = var.avdLocation
#   #subnet_id          = var.pesubnet_id
#   subnet_id = "/subscriptions/${var.spoke_subscription_id}/resourceGroups/${var.rg_network}/providers/Microsoft.Network/virtualNetworks/${var.vnet_name}/subnets/${var.pesubnet_hostpool1}"
#   tags      = var.tags

#   private_service_connection {
#     name = "psc-hp-${var.prefix}"
#     #private_connection_resource_id = module.avm_res_desktopvirtualization_hostpool.resource_id
#     private_connection_resource_id = azurerm_virtual_desktop_host_pool.this.id
#     is_manual_connection           = false
#     subresource_names              = ["connection"]
#   }

#   private_dns_zone_group {
#     name                 = "dns-hp-${var.prefix}"
#     private_dns_zone_ids = [data.azurerm_private_dns_zone.avd_feed_dns.id]
#   }
#   depends_on = [azurerm_virtual_desktop_host_pool.this]
#   lifecycle { prevent_destroy = false }
# }


# resource "time_offset" "avd_registration_token_expiry" {
#   count = var.avd_host_pool_id == null ? 0 : 1

#   offset_hours = var.avd_registration_token_expiry_hours
# }

# resource "azurerm_virtual_desktop_host_pool_registration_info" "avd" {
#   count = var.avd_host_pool_id == null ? 0 : 1

#   hostpool_id     = var.avd_host_pool_id
#   expiration_date = time_offset.avd_registration_token_expiry[0].rfc3339
# }


# resource "random_password" "local" {
#   length           = var.local_password_length
#   special          = true
#   override_special = "!#$%&*()-_=+[]{}<>:?"
# }

# locals {
#   key_vault_secrets = merge(
#     {
#       local_password = {
#         name = var.local_password_secret_name
#       }
#     },
#     var.avd_host_pool_id == null ? {} : {
#       avd_registration_token = {
#         name            = var.avd_registration_token_secret_name
#         content_type    = "AVD host pool registration token"
#         expiration_date = time_offset.avd_registration_token_expiry[0].rfc3339
#       }
#     }
#   )

#   key_vault_secret_values = merge(
#     {
#       local_password = random_password.local.result
#     },
#     var.avd_host_pool_id == null ? {} : {
#       avd_registration_token = azurerm_virtual_desktop_host_pool_registration_info.avd[0].token
#     }
#   )
# }

# # resource "time_sleep" "wait_for_private_link" {
# #   create_duration = var.private_link_secret_wait_duration

# #   depends_on = [
# #     module.key_vault,
# #     azurerm_private_dns_zone_virtual_network_link.key_vault
# #   ]
# # }

# data "avm_res_keyvault_vault" "key_vault" {
#   name                = var.keyvault_name
#   resource_group_name = azurerm_resource_group.service_objects.name
# }

# resource "azurerm_key_vault_secret" "this" {
#   for_each = local.key_vault_secrets

#   name            = each.value.name
#   value           = local.key_vault_secret_values[each.key]
#   key_vault_id    = data.avm_res_keyvault_vault.key_vault.id
#   content_type    = try(each.value.content_type, null)
#   expiration_date = try(each.value.expiration_date, null)

#   # depends_on = [time_sleep.wait_for_private_link]
# }





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