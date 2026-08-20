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

data "azurerm_private_dns_zone" "avd_feed_dns" {
  provider = azurerm.hub

  name                = "privatelink.wvd.microsoft.com"
  resource_group_name = var.hub_dns_zone_rg
}

data "azuread_group" "avd_users" {
  display_name     = var.avd_users_group
  security_enabled = true
}

locals {
  session_host_configuration = merge(
    var.session_host_configuration,
    {
      networkInfo = merge(
        lookup(var.session_host_configuration, "networkInfo", {}),
        {
          subnetId = "/subscriptions/${var.spoke_subscription_id}/resourceGroups/${var.rg_network}/providers/Microsoft.Network/virtualNetworks/${var.vnet_name}/subnets/${var.session_host_subnet_name}"
        }
      )
    }
  )

  scaling_plan_properties = merge(
    {
      description  = var.scaling_plan_description
      friendlyName = var.scaling_plan_friendly_name
      hostPoolType = "Pooled"
      timeZone     = var.scaling_plan_time_zone

      hostPoolReferences = [
        {
          hostPoolArmPath    = azapi_resource.host_pool.id
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

resource "azurerm_role_assignment" "avd_reader" {
  scope                            = "/subscriptions/${var.spoke_subscription_id}"
  role_definition_name             = "Reader"
  principal_id                     = var.avd_service_principal_object_id
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "avd_vm_on_off_contributor" {
  scope                            = "/subscriptions/${var.spoke_subscription_id}"
  role_definition_name             = "Desktop Virtualization Power On Off Contributor"
  principal_id                     = var.avd_service_principal_object_id
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "avd_vm_contributor" {
  scope                            = "/subscriptions/${var.spoke_subscription_id}"
  role_definition_name             = "Desktop Virtualization Virtual Machine Contributor"
  principal_id                     = var.avd_service_principal_object_id
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "avd_network_contributor" {
  scope                            = "/subscriptions/${var.spoke_subscription_id}"
  role_definition_name             = "Network Contributor"
  principal_id                     = var.avd_service_principal_object_id
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "avd_keyvault_secrets_user" {
  scope                            = data.azurerm_key_vault.session_host_secrets.id
  role_definition_name             = "Key Vault Secrets User"
  principal_id                     = var.avd_service_principal_object_id
  skip_service_principal_aad_check = true
}

resource "azurerm_resource_group" "compute" {
  location = var.avdLocation
  name     = var.rg_pool
  tags     = var.tags
}

resource "azapi_resource" "host_pool" {
  type      = "Microsoft.DesktopVirtualization/hostPools@2026-04-01-preview"
  name      = var.hostpool_name
  location  = var.avdLocation
  parent_id = azurerm_resource_group.compute.id
  tags      = var.tags

  identity {
    type = "SystemAssigned"
  }

  body = {
    properties = {
      hostPoolType          = var.hostpool_type
      loadBalancerType      = var.hostpool_load_balancer_type
      maxSessionLimit       = var.hostpool_maximum_sessions_allowed
      startVMOnConnect      = var.hostpool_start_vm_on_connect
      validationEnvironment = var.hostpool_validate_environment
      customRdpProperty     = var.hostpool_custom_rdp_properties
      publicNetworkAccess   = "Disabled"
      preferredAppGroupType = var.app_group_type == "Desktop" ? "Desktop" : "RailApplications"
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

resource "azurerm_role_assignment" "host_pool_mi_vm_contributor" {
  scope                = azurerm_resource_group.compute.id
  role_definition_name = "Desktop Virtualization Virtual Machine Contributor"
  principal_id         = azapi_resource.host_pool.identity[0].principal_id
}

resource "azurerm_role_assignment" "host_pool_mi_network_contributor" {
  scope                = "/subscriptions/${var.spoke_subscription_id}"
  role_definition_name = "Network Contributor"
  principal_id         = azapi_resource.host_pool.identity[0].principal_id
}

resource "azurerm_role_assignment" "host_pool_mi_subscription_reader" {
  scope                = "/subscriptions/${var.spoke_subscription_id}"
  role_definition_name = "Reader"
  principal_id         = azapi_resource.host_pool.identity[0].principal_id
}

resource "azurerm_role_assignment" "host_pool_mi_keyvault_secrets_user" {
  scope                = data.azurerm_key_vault.session_host_secrets.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azapi_resource.host_pool.identity[0].principal_id
}

resource "azapi_resource" "session_host_configuration" {
  type      = "Microsoft.DesktopVirtualization/hostPools/sessionHostConfigurations@2026-04-01-preview"
  name      = "default"
  parent_id = azapi_resource.host_pool.id

  body = {
    properties = local.session_host_configuration
  }

  depends_on = [
    azurerm_role_assignment.avd_reader,
    azurerm_role_assignment.avd_vm_on_off_contributor,
    azurerm_role_assignment.avd_vm_contributor,
    azurerm_role_assignment.avd_keyvault_secrets_user,
    azurerm_role_assignment.avd_network_contributor,
    azurerm_role_assignment.host_pool_mi_network_contributor,
    azurerm_role_assignment.host_pool_mi_vm_contributor,
    azurerm_role_assignment.host_pool_mi_subscription_reader,
    azurerm_role_assignment.host_pool_mi_keyvault_secrets_user
  ]
}

resource "azapi_resource" "session_host_management" {
  type      = "Microsoft.DesktopVirtualization/hostPools/sessionHostManagements@2026-04-01-preview"
  name      = "default"
  parent_id = azapi_resource.host_pool.id

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

resource "azurerm_virtual_desktop_application_group" "this" {
  name                         = var.app_group_name
  location                     = var.avdLocation
  resource_group_name          = azurerm_resource_group.compute.name
  type                         = var.app_group_type
  host_pool_id                 = azapi_resource.host_pool.id
  default_desktop_display_name = var.app_group_default_desktop_display_name
  tags                         = var.tags
}

resource "azurerm_role_assignment" "avd_users" {
  scope                = azurerm_virtual_desktop_application_group.this.id
  role_definition_name = "Desktop Virtualization User"
  principal_id         = data.azuread_group.avd_users.object_id
}

resource "azurerm_role_assignment" "avd_users_vm_login" {
  scope                = azurerm_resource_group.compute.id
  role_definition_name = "Virtual Machine User Login"
  principal_id         = data.azuread_group.avd_users.object_id
}

resource "azurerm_virtual_desktop_workspace_application_group_association" "this" {
  workspace_id         = data.azurerm_virtual_desktop_workspace.this.id
  application_group_id = azurerm_virtual_desktop_application_group.this.id
}

resource "azurerm_private_endpoint" "workspace_feed" {
  count = var.enable_private_endpoints ? 1 : 0

  name                = var.workspace_feed_private_endpoint_name
  resource_group_name = data.azurerm_resource_group.service_objects.name
  location            = var.avdLocation
  subnet_id           = "/subscriptions/${var.spoke_subscription_id}/resourceGroups/${var.rg_network}/providers/Microsoft.Network/virtualNetworks/${var.vnet_name}/subnets/${var.workspace_private_endpoint_subnet_name}"
  tags                = var.tags

  private_service_connection {
    name                           = var.workspace_feed_private_service_connection_name
    private_connection_resource_id = data.azurerm_virtual_desktop_workspace.this.id
    is_manual_connection           = false
    subresource_names              = ["feed"]
  }

  private_dns_zone_group {
    name                 = var.workspace_feed_private_dns_zone_group_name
    private_dns_zone_ids = [data.azurerm_private_dns_zone.avd_feed_dns.id]
  }
}

resource "azurerm_private_endpoint" "hostpool_connection" {
  count = var.enable_private_endpoints ? 1 : 0

  name                = var.hostpool_private_endpoint_name
  resource_group_name = azurerm_resource_group.compute.name
  location            = var.avdLocation
  subnet_id           = "/subscriptions/${var.spoke_subscription_id}/resourceGroups/${var.rg_network}/providers/Microsoft.Network/virtualNetworks/${var.vnet_name}/subnets/${var.hostpool_private_endpoint_subnet_name}"
  tags                = var.tags

  private_service_connection {
    name                           = var.hostpool_private_service_connection_name
    private_connection_resource_id = azapi_resource.host_pool.id
    is_manual_connection           = false
    subresource_names              = ["connection"]
  }

  private_dns_zone_group {
    name                 = var.hostpool_private_dns_zone_group_name
    private_dns_zone_ids = [data.azurerm_private_dns_zone.avd_feed_dns.id]
  }

  depends_on = [
    azapi_resource.host_pool
  ]
}

resource "azapi_resource" "dynamic_scaling_plan" {
  count = var.enable_dynamic_scaling_plan ? 1 : 0

  type      = "Microsoft.DesktopVirtualization/scalingPlans@2026-04-01-preview"
  name      = var.scaling_plan_name
  location  = var.avdLocation
  parent_id = azurerm_resource_group.compute.id
  tags      = var.tags

  body = {
    properties = local.scaling_plan_properties
  }

  lifecycle {
    ignore_changes = [body]
  }

  depends_on = [
    azurerm_role_assignment.avd_reader,
    azurerm_role_assignment.avd_vm_on_off_contributor,
    azurerm_role_assignment.avd_vm_contributor,
    azurerm_role_assignment.avd_keyvault_secrets_user,
    azurerm_role_assignment.avd_network_contributor,
    azurerm_role_assignment.host_pool_mi_network_contributor,
    azurerm_role_assignment.host_pool_mi_vm_contributor,
    azurerm_role_assignment.host_pool_mi_subscription_reader,
    azurerm_role_assignment.host_pool_mi_keyvault_secrets_user,
    azapi_resource.session_host_management
  ]
}
