# ── AVD Host Pool, Application Group, Workspace, Scaling Plan ─────────────────
# Depends on: 01-resource-groups (rg_service_objects_name), 03-monitoring (log_analytics_workspace_id)
# Provides:   hostpool_id, registration_token, application_group_id, workspace_id
#             → consumed by 07-session-hosts, 08-rbac
#
# CRITICAL: Entra SSO properties (enablerdsaadauth, targetisaadjoined) MUST be in
#           custom_properties{} map — NOT in custom_rdp_properties typed object.
#           The AVM typed object only supports 11 named fields and silently drops anything else.


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

data "azurerm_client_config" "current" {}



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

  scope                = "/subscriptions/${var.spoke_subscription_id}"
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
  default_vm_admin_credentials = coalesce(var.session_host_vm_admin_credentials, {
    usernameKeyVaultSecretUri = "https://${var.key_vault_name}.vault.azure.net/secrets/vm-local-admin-username"
    passwordKeyVaultSecretUri = "https://${var.key_vault_name}.vault.azure.net/secrets/local-password"
  })

  host_pool_defaults = {
    resource_group_name                    = null
    tags                                   = {}
    avd_users_group                        = null
    app_group_default_desktop_display_name = null
    app_group_type                         = null
    hostpool_type                          = null
    hostpool_load_balancer_type            = null
    hostpool_maximum_sessions_allowed      = null
    hostpool_start_vm_on_connect           = null
    hostpool_validate_environment          = null
    hostpool_custom_rdp_properties         = null
    session_host_subnet_name               = null
    hostpool_private_endpoint_subnet_name  = null
    session_host_configuration             = {}
    create_registration_token              = null
    registration_token_ttl                 = null
    scaling_plan_name                      = null
    scaling_plan_friendly_name             = null
    scaling_plan_description               = null
    dynamic_scaling_plan_schedules         = null
  }

  host_pools_from_var = {
    for host_pool in var.host_pools : host_pool.name => merge(
      local.host_pool_defaults,
      host_pool,
      {
        tags = merge(var.tags, try(host_pool.tags, {}))

        session_host_configuration = merge(
          {
            diskInfo            = var.session_host_disk_info
            securityInfo        = var.session_host_security_info
            bootDiagnosticsInfo = var.session_host_boot_diagnostics_info
            vmAdminCredentials  = local.default_vm_admin_credentials
          },
          try(host_pool.session_host_configuration, {}),
          {
            networkInfo = merge(
              try(host_pool.session_host_configuration.networkInfo, {}),
              {
                subnetId = "/subscriptions/${var.spoke_subscription_id}/resourceGroups/${var.rg_network}/providers/Microsoft.Network/virtualNetworks/${var.vnet_name}/subnets/${host_pool.session_host_subnet_name}"
              }
            )
            vmTags = merge(
              var.tags,
              try(host_pool.session_host_configuration.vmTags, {})
            )
          }
        )
      }
    )
  }

  legacy_host_pool_names = length(var.host_pools) == 0 && var.hostpool_name != null && var.app_group_name != null ? toset([var.hostpool_name]) : toset([])

  legacy_host_pools = {
    for hostpool_name in local.legacy_host_pool_names : hostpool_name => {
      name                                   = var.hostpool_name
      resource_group_name                    = var.rg_pool
      tags                                   = var.tags
      avd_users_group                        = var.avd_users_group
      app_group_name                         = var.app_group_name
      app_group_default_desktop_display_name = var.app_group_default_desktop_display_name
      app_group_type                         = var.app_group_type
      hostpool_type                          = var.hostpool_type
      hostpool_load_balancer_type            = var.hostpool_load_balancer_type
      hostpool_maximum_sessions_allowed      = var.hostpool_maximum_sessions_allowed
      hostpool_start_vm_on_connect           = var.hostpool_start_vm_on_connect
      hostpool_validate_environment          = var.hostpool_validate_environment
      hostpool_custom_rdp_properties         = var.hostpool_custom_rdp_properties
      session_host_subnet_name               = null
      hostpool_private_endpoint_subnet_name  = var.hostpool_private_endpoint_subnet_name
      session_host_configuration             = var.host_pool_vm_template
      create_registration_token              = var.create_registration_token
      registration_token_ttl                 = var.registration_token_ttl
      scaling_plan_name                      = var.scaling_plan_name
      scaling_plan_friendly_name             = var.scaling_plan_friendly_name
      scaling_plan_description               = var.scaling_plan_description
      dynamic_scaling_plan_schedules         = var.dynamic_scaling_plan_schedules
    }
  }

  host_pools = merge(local.host_pools_from_var, local.legacy_host_pools)
}

data "azuread_group" "avd_users" {
  for_each = local.host_pools

  display_name     = coalesce(each.value.avd_users_group, var.avd_users_group)
  security_enabled = true
}

resource "azurerm_resource_group" "compute" {
  for_each = local.host_pools

  location = var.avdLocation
  name     = coalesce(each.value.resource_group_name, "rg-${each.value.name}-${var.environment}")
  tags     = each.value.tags
  lifecycle { prevent_destroy = false }
}

resource "azurerm_policy_definition" "session_host_encryption_at_host" {
  count = var.enable_session_host_encryption_at_host_policy ? 1 : 0

  name         = "avd-session-host-encryption-at-host-${coalesce(var.environment, "env")}"
  policy_type  = "Custom"
  mode         = "Indexed"
  display_name = "Configure encryption at host for AVD session hosts"
  description  = "Adds securityProfile.encryptionAtHost=true to Microsoft.Compute/virtualMachines requests so dynamically created AVD session hosts are encrypted at host from creation."

  parameters = jsonencode({
    effect = {
      type          = "String"
      defaultValue  = "Modify"
      allowedValues = ["Modify", "Audit", "Disabled"]
      metadata = {
        displayName = "Effect"
        description = "Use Modify to patch VM creation/update requests, Audit to report only, or Disabled to turn off this policy."
      }
    }
  })

  policy_rule = jsonencode({
    if = {
      allOf = [
        {
          field  = "type"
          equals = "Microsoft.Compute/virtualMachines"
        },
        {
          field     = "Microsoft.Compute/virtualMachines/securityProfile.encryptionAtHost"
          notEquals = true
        }
      ]
    }
    then = {
      effect = "[parameters('effect')]"
      details = {
        conflictEffect = "audit"
        roleDefinitionIds = [
          "/providers/Microsoft.Authorization/roleDefinitions/9980e02c-c2be-4d73-94e8-173b1dc7cf3c"
        ]
        operations = [
          {
            operation = "AddOrReplace"
            field     = "Microsoft.Compute/virtualMachines/securityProfile.encryptionAtHost"
            value     = true
          }
        ]
      }
    }
  })
}

resource "azurerm_resource_group_policy_assignment" "session_host_encryption_at_host" {
  for_each = var.enable_session_host_encryption_at_host_policy ? local.host_pools : {}

  name                 = "pa-avd-eah-${each.key}"
  resource_group_id    = azurerm_resource_group.compute[each.key].id
  policy_definition_id = azurerm_policy_definition.session_host_encryption_at_host[0].id
  location             = var.avdLocation
  display_name         = "Configure encryption at host for ${each.value.name} session hosts"
  description          = "Ensures VMs created by AVD dynamic host pool management in this resource group have encryption at host enabled at creation time."

  identity {
    type = "SystemAssigned"
  }

  parameters = jsonencode({
    effect = {
      value = "Modify"
    }
  })
}

resource "azurerm_role_assignment" "session_host_encryption_policy_vm_contributor" {
  for_each = var.enable_session_host_encryption_at_host_policy ? local.host_pools : {}

  scope                = azurerm_resource_group.compute[each.key].id
  role_definition_name = "Virtual Machine Contributor"
  principal_id         = azurerm_resource_group_policy_assignment.session_host_encryption_at_host[each.key].identity[0].principal_id

  skip_service_principal_aad_check = true
}

resource "azapi_resource" "host_pool" {
  for_each = local.host_pools

  type      = "Microsoft.DesktopVirtualization/hostPools@2026-04-01-preview"
  name      = each.value.name
  location  = var.avdLocation
  parent_id = azurerm_resource_group.compute[each.key].id
  tags      = each.value.tags

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
    azurerm_role_assignment.host_pool_mi_network_contributor,
    azurerm_role_assignment.host_pool_mi_vm_contributor,
    azurerm_role_assignment.host_pool_mi_subscription_reader,
    azurerm_role_assignment.host_pool_mi_keyvault_secrets_user
  ]
}

resource "terraform_data" "session_host_management" {
  for_each = local.host_pools

  input = {
    resource_id = "${azapi_resource.host_pool[each.key].id}/sessionHostManagements/default"
    body = jsonencode({
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
    })
  }

  triggers_replace = [
    azapi_resource.host_pool[each.key].id,
    var.scaling_plan_time_zone,
    jsonencode({
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
    })
  ]

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      az rest \
        --method put \
        --url "https://management.azure.com${self.input.resource_id}?api-version=2026-04-01-preview" \
        --headers "Content-Type=application/json" \
        --body '${self.input.body}'
    EOT
  }

  depends_on = [
    azapi_resource.session_host_configuration,
    azurerm_role_assignment.session_host_encryption_policy_vm_contributor
  ]
}

removed {
  from = azapi_resource.session_host_management

  lifecycle {
    destroy = false
  }
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
  tags                         = each.value.tags
}

resource "azurerm_role_assignment" "avd_users" {
  for_each = local.host_pools

  scope                = azurerm_virtual_desktop_application_group.this[each.key].id
  role_definition_name = "Desktop Virtualization User"
  principal_id         = data.azuread_group.avd_users[each.key].object_id
}

resource "azurerm_role_assignment" "avd_users_vm_login" {
  for_each = local.host_pools

  scope                = azurerm_resource_group.compute[each.key].id
  role_definition_name = "Virtual Machine User Login"
  principal_id         = data.azuread_group.avd_users[each.key].object_id
}

resource "azurerm_virtual_desktop_workspace_application_group_association" "this" {
  for_each = local.host_pools

  workspace_id         = data.azurerm_virtual_desktop_workspace.this.id
  application_group_id = azurerm_virtual_desktop_application_group.this[each.key].id
}

resource "azurerm_private_endpoint" "hostpool_connection" {
  for_each = {
    for name, host_pool in local.host_pools : name => host_pool
    if var.enable_private_endpoints
  }

  name                = "pe-avd-hp-${each.value.name}"
  resource_group_name = azurerm_resource_group.compute[each.key].name
  location            = var.avdLocation
  subnet_id           = "/subscriptions/${var.spoke_subscription_id}/resourceGroups/${var.rg_network}/providers/Microsoft.Network/virtualNetworks/${var.vnet_name}/subnets/${coalesce(each.value.hostpool_private_endpoint_subnet_name, each.value.session_host_subnet_name, var.hostpool_private_endpoint_subnet_name)}"
  tags                = each.value.tags

  private_service_connection {
    name                           = "psc-avd-hp-${each.value.name}"
    private_connection_resource_id = azapi_resource.host_pool[each.key].id
    is_manual_connection           = false
    subresource_names              = ["connection"]
  }

  private_dns_zone_group {
    name                 = "dns-avd-hp-${each.value.name}"
    private_dns_zone_ids = [data.azurerm_private_dns_zone.avd_feed_dns.id]
  }

  depends_on = [
    azapi_resource.host_pool
  ]
}



resource "azapi_resource" "dynamic_scaling_plan" {
  for_each = {
    for name, host_pool in local.host_pools : name => host_pool
    if var.enable_dynamic_scaling_plan
  }

  type      = "Microsoft.DesktopVirtualization/scalingPlans@2026-04-01-preview"
  name      = coalesce(each.value.scaling_plan_name, var.scaling_plan_name, "sp-${each.value.name}")
  location  = var.avdLocation
  parent_id = azurerm_resource_group.compute[each.key].id
  tags      = each.value.tags

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

        schedules = coalesce(each.value.dynamic_scaling_plan_schedules, var.dynamic_scaling_plan_schedules)
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
    azurerm_role_assignment.host_pool_mi_network_contributor,
    azurerm_role_assignment.host_pool_mi_vm_contributor,
    azurerm_role_assignment.host_pool_mi_subscription_reader,
    azurerm_role_assignment.host_pool_mi_keyvault_secrets_user,
    terraform_data.session_host_management
  ]
}
