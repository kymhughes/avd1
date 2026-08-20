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

data "azurerm_virtual_desktop_workspace" "this" {
  name                = var.workspace_name
  resource_group_name = coalesce(var.workspace_resource_group_name, var.rg_so)
}

data "azurerm_client_config" "current" {}

#Assign nesssesary roles to the AVD service principal for dynamic autoscale to work
resource "azurerm_role_assignment" "avd_reader" {
  scope                            = "/subscriptions/${var.spoke_subscription_id}"
  role_definition_name             = "Reader"
  principal_id                     = var.avd_service_principal_object_id
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "avd_vm_contributor" {
  scope                            = "/subscriptions/${var.spoke_subscription_id}"
  role_definition_name             = "Desktop Virtualization Virtual Machine Contributor"
  principal_id                     = var.avd_service_principal_object_id
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "avd_keyvault_secrets_user" {
  scope                            = var.key_vault_id
  role_definition_name             = "Key Vault Secrets User"
  principal_id                     = var.avd_service_principal_object_id
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "avd_network_reader" {
  scope                            = "/subscriptions/${var.spoke_subscription_id}/resourceGroups/${var.network_resource_group_name}"
  role_definition_name             = "Reader"
  principal_id                     = var.avd_service_principal_object_id
  skip_service_principal_aad_check = true
}

resource "time_sleep" "wait_for_avd_rbac" {
  create_duration = "300s"

  depends_on = [
    azurerm_role_assignment.avd_reader,
    azurerm_role_assignment.avd_vm_contributor,
    azurerm_role_assignment.avd_keyvault_secrets_user,
    azurerm_role_assignment.avd_network_reader
  ]
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
    time_sleep.wait_for_avd_rbac,
    azurerm_role_assignment.host_pool_mi_vm_contributor
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

resource "azurerm_role_assignment" "host_pool_mi_vm_contributor" {
  for_each = local.host_pools

  scope                = azurerm_resource_group.compute[each.key].id
  role_definition_name = "Desktop Virtualization Virtual Machine Contributor"
  principal_id         = azapi_resource.host_pool[each.key].identity[0].principal_id
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
    time_sleep.wait_for_avd_rbac,
    azurerm_role_assignment.host_pool_mi_vm_contributor,
    azapi_resource.session_host_configuration
  ]
}
