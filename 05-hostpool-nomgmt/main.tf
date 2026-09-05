# ── AVD Host Pool, Application Group, Workspace, Scaling Plan ─────────────────
# Depends on: 01-resource-groups (rg_service_objects_name), 03-monitoring (log_analytics_workspace_id)
# Provides:   hostpool_id, application_group_id, workspace_id
#             → consumed by 07-session-hosts, 08-rbac


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

resource "azurerm_user_assigned_identity" "session_hosts" {
  count = var.enable_session_host_uami_policy ? 1 : 0

  name                = var.session_host_uami_name
  location            = var.avdLocation
  resource_group_name = var.rg_so
  tags                = var.tags
}

resource "azurerm_role_assignment" "session_hosts_blob_reader" {
  count = var.enable_session_host_uami_policy && var.session_host_uami_storage_scope != null ? 1 : 0

  scope                = var.session_host_uami_storage_scope
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = azurerm_user_assigned_identity.session_hosts[0].principal_id
}

resource "azurerm_policy_definition" "assign_session_host_uami" {
  count = var.enable_session_host_uami_policy ? 1 : 0

  name         = "assign-avd-session-host-uami-${coalesce(var.environment, "env")}"
  policy_type  = "Custom"
  mode         = "Indexed"
  display_name = "Assign user-assigned managed identity to AVD session hosts"
  description  = "Adds the shared session host user-assigned managed identity to AVD-created session host VMs matched by workload tag."

  parameters = jsonencode({
    effect = {
      type          = "String"
      defaultValue  = "Modify"
      allowedValues = ["Modify", "Audit", "Disabled"]
      metadata = {
        displayName = "Effect"
        description = "Use Modify to assign the managed identity, Audit to report only, or Disabled to turn off this policy."
      }
    }
  })

  policy_rule = jsonencode({
    if = {
      field  = "type"
      equals = "Microsoft.Compute/virtualMachines"
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
            operation = "addOrReplace"
            field     = "identity.type"
            value     = "UserAssigned"
          },
          {
            operation = "addOrReplace"
            field     = "identity.userAssignedIdentities"
            value = {
              (azurerm_user_assigned_identity.session_hosts[0].id) = {}
            }
          }
        ]
      }
    }
  })
}

resource "azurerm_resource_group_policy_assignment" "assign_session_host_uami" {
  for_each = var.enable_session_host_uami_policy ? local.host_pools : {}

  name                 = "pa-avd-uami-${each.key}"
  resource_group_id    = data.azurerm_resource_group.compute[each.key].id
  policy_definition_id = azurerm_policy_definition.assign_session_host_uami[0].id
  location             = var.avdLocation
  display_name         = "Assign managed identity to ${each.value.name} session hosts"
  description          = "Assigns ${var.session_host_uami_name} to VMs in the pool resource group."

  identity {
    type = "SystemAssigned"
  }

  parameters = jsonencode({
    effect = {
      value = "Modify"
    }
  })
}

resource "azurerm_role_assignment" "session_host_uami_policy_vm_contributor" {
  for_each = var.enable_session_host_uami_policy ? local.host_pools : {}

  scope                = data.azurerm_resource_group.compute[each.key].id
  role_definition_name = "Virtual Machine Contributor"
  principal_id         = azurerm_resource_group_policy_assignment.assign_session_host_uami[each.key].identity[0].principal_id

  skip_service_principal_aad_check = true
}

resource "azurerm_policy_definition" "deploy_session_host_bootstrap_extension" {
  for_each = local.bootstrap_host_pools

  name         = "deploy-avd-session-host-bootstrap-${each.key}"
  policy_type  = "Custom"
  mode         = "Indexed"
  display_name = "Deploy bootstrap extension to ${each.value.name} session hosts"
  description  = "Deploys Custom Script Extension to ${each.value.name} session host VMs. The script uses the assigned UAMI to download bootstrap content from private blob storage."

  parameters = jsonencode({
    effect = {
      type          = "String"
      defaultValue  = "DeployIfNotExists"
      allowedValues = ["DeployIfNotExists", "AuditIfNotExists", "Disabled"]
      metadata = {
        displayName = "Effect"
        description = "Use DeployIfNotExists to deploy the bootstrap extension, AuditIfNotExists to report only, or Disabled to turn off this policy."
      }
    }
  })

  policy_rule = jsonencode({
    if = {
      field  = "type"
      equals = "Microsoft.Compute/virtualMachines"
    }
    then = {
      effect = "[parameters('effect')]"
      details = {
        type = "Microsoft.Compute/virtualMachines/extensions"
        name = "[concat(field('name'), '/${var.session_host_bootstrap_extension_name}')]"
        roleDefinitionIds = [
          "/providers/Microsoft.Authorization/roleDefinitions/9980e02c-c2be-4d73-94e8-173b1dc7cf3c"
        ]
        existenceCondition = {
          allOf = [
            {
              field  = "Microsoft.Compute/virtualMachines/extensions/publisher"
              equals = "Microsoft.Compute"
            },
            {
              field  = "Microsoft.Compute/virtualMachines/extensions/type"
              equals = "CustomScriptExtension"
            },
            {
              field  = "Microsoft.Compute/virtualMachines/extensions/provisioningState"
              equals = "Succeeded"
            }
          ]
        }
        deployment = {
          properties = {
            mode = "incremental"
            parameters = {
              vmName = {
                value = "[field('name')]"
              }
              location = {
                value = "[field('location')]"
              }
              extensionName = {
                value = var.session_host_bootstrap_extension_name
              }
              commandToExecute = {
                value = "powershell.exe -ExecutionPolicy Bypass -NoProfile -Command \"$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue'; $root = 'C:\\ProgramData\\AVD-Bootstrap'; New-Item -ItemType Directory -Force -Path $root | Out-Null; $token = $null; for ($i = 1; $i -le 30 -and -not $token; $i++) { try { $token = Invoke-RestMethod -Headers @{ Metadata = 'true' } -Uri 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://storage.azure.com/&client_id=${azurerm_user_assigned_identity.session_hosts[0].client_id}' -TimeoutSec 10 } catch { Start-Sleep -Seconds 20 } }; if (-not $token) { throw 'Managed identity token was not available.' }; $headers = @{ Authorization = ('Bearer ' + $token.access_token); 'x-ms-version' = '2023-11-03' }; $scriptPath = Join-Path $root 'bootstrap.ps1'; Invoke-WebRequest -Uri '${each.value.bootstrap_script_url}' -Headers $headers -OutFile $scriptPath; & powershell.exe -ExecutionPolicy Bypass -NoProfile -File $scriptPath\""
              }
            }
            template = {
              "$schema"      = "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#"
              contentVersion = "1.0.0.0"
              parameters = {
                vmName = {
                  type = "string"
                }
                location = {
                  type = "string"
                }
                extensionName = {
                  type = "string"
                }
                commandToExecute = {
                  type = "string"
                }
              }
              resources = [
                {
                  type       = "Microsoft.Compute/virtualMachines/extensions"
                  apiVersion = "2023-09-01"
                  name       = "[concat(parameters('vmName'), '/', parameters('extensionName'))]"
                  location   = "[parameters('location')]"
                  properties = {
                    publisher               = "Microsoft.Compute"
                    type                    = "CustomScriptExtension"
                    typeHandlerVersion      = "1.10"
                    autoUpgradeMinorVersion = true
                    settings = {
                      commandToExecute = "[parameters('commandToExecute')]"
                    }
                  }
                }
              ]
            }
          }
        }
      }
    }
  })
}

resource "azurerm_resource_group_policy_assignment" "deploy_session_host_bootstrap_extension" {
  for_each = local.bootstrap_host_pools

  name                 = "pa-avd-bootstrap-${each.key}"
  resource_group_id    = data.azurerm_resource_group.compute[each.key].id
  policy_definition_id = azurerm_policy_definition.deploy_session_host_bootstrap_extension[each.key].id
  location             = var.avdLocation
  display_name         = "Deploy bootstrap extension to ${each.value.name} session hosts"
  description          = "Deploys Custom Script Extension to VMs in the pool resource group."

  identity {
    type = "SystemAssigned"
  }

  parameters = jsonencode({
    effect = {
      value = "DeployIfNotExists"
    }
  })

  depends_on = [
    azurerm_resource_group_policy_assignment.assign_session_host_uami,
    azurerm_role_assignment.session_host_uami_policy_vm_contributor,
    azurerm_role_assignment.session_hosts_blob_reader
  ]
}

resource "azurerm_role_assignment" "session_host_bootstrap_policy_vm_contributor" {
  for_each = local.bootstrap_host_pools

  scope                = data.azurerm_resource_group.compute[each.key].id
  role_definition_name = "Virtual Machine Contributor"
  principal_id         = azurerm_resource_group_policy_assignment.deploy_session_host_bootstrap_extension[each.key].identity[0].principal_id

  skip_service_principal_aad_check = true
}

###################################################################################
#Assign nesssesary roles for each Session Pool Managed ID for dynamic autoscale to work
###################################################################################

# resource group VM Contributor
resource "azurerm_role_assignment" "host_pool_mi_vm_contributor" {
  for_each = local.host_pools

  scope                = data.azurerm_resource_group.compute[each.key].id
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
    remote_apps                            = []
    bootstrap_script_url                   = null
    hostpool_type                          = null
    hostpool_load_balancer_type            = null
    hostpool_maximum_sessions_allowed      = null
    hostpool_start_vm_on_connect           = null
    hostpool_validate_environment          = null
    hostpool_custom_rdp_properties         = null
    session_host_subnet_name               = null
    hostpool_private_endpoint_subnet_name  = null
    session_host_configuration             = {}
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

  host_pools = local.host_pools_from_var

  remote_apps = flatten([
    for host_pool_name, host_pool in local.host_pools : [
      for app in host_pool.remote_apps : merge(app, {
        host_pool_name = host_pool_name
      })
    ] if coalesce(host_pool.app_group_type, var.app_group_type) == "RemoteApp"
  ])

  bootstrap_host_pools = {
    for name, host_pool in local.host_pools : name => host_pool
    if var.enable_session_host_bootstrap_extension_policy && host_pool.bootstrap_script_url != null
  }
}

data "azuread_group" "avd_users" {
  for_each = local.host_pools

  display_name     = coalesce(each.value.avd_users_group, var.avd_users_group)
  security_enabled = true
}

resource "terraform_data" "compute_resource_group" {
  for_each = local.host_pools

  input = {
    name = coalesce(each.value.resource_group_name, "rg-${each.value.name}-${var.environment}")
    body = jsonencode({
      location = var.avdLocation
      tags     = each.value.tags
    })
  }

  triggers_replace = [
    coalesce(each.value.resource_group_name, "rg-${each.value.name}-${var.environment}"),
    var.avdLocation,
    jsonencode(each.value.tags)
  ]

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      az rest \
        --method put \
        --url "https://management.azure.com/subscriptions/${var.spoke_subscription_id}/resourceGroups/${self.input.name}?api-version=2021-04-01" \
        --headers "Content-Type=application/json" \
        --body '${self.input.body}'
    EOT
  }
}

data "azurerm_resource_group" "compute" {
  for_each = local.host_pools

  name = terraform_data.compute_resource_group[each.key].input.name

  depends_on = [
    terraform_data.compute_resource_group
  ]
}

resource "azapi_resource" "host_pool" {
  for_each = local.host_pools

  type      = "Microsoft.DesktopVirtualization/hostPools@2026-04-01-preview"
  name      = each.value.name
  location  = var.avdLocation
  parent_id = data.azurerm_resource_group.compute[each.key].id
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
    properties = each.value.session_host_configuration
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
    azapi_resource.session_host_configuration
  ]
}

# ── Application Groups ────────────────────────────────────────────────────────
resource "azurerm_virtual_desktop_application_group" "this" {
  for_each = local.host_pools

  name                         = each.value.app_group_name
  location                     = var.avdLocation
  resource_group_name          = data.azurerm_resource_group.compute[each.key].name
  type                         = coalesce(each.value.app_group_type, var.app_group_type)
  host_pool_id                 = azapi_resource.host_pool[each.key].id
  default_desktop_display_name = coalesce(each.value.app_group_type, var.app_group_type) == "Desktop" ? coalesce(each.value.app_group_default_desktop_display_name, var.app_group_default_desktop_display_name) : null
  tags                         = each.value.tags
}

resource "azurerm_virtual_desktop_application" "remote_apps" {
  for_each = {
    for app in local.remote_apps : "${app.host_pool_name}-${app.name}" => app
  }

  name                         = each.value.name
  application_group_id         = azurerm_virtual_desktop_application_group.this[each.value.host_pool_name].id
  friendly_name                = try(each.value.friendly_name, each.value.name)
  description                  = try(each.value.description, null)
  path                         = each.value.path
  command_line_argument_policy = try(each.value.command_line_argument_policy, "DoNotAllow")
  command_line_arguments       = try(each.value.command_line_arguments, null)
  show_in_portal               = try(each.value.show_in_portal, true)
  icon_path                    = try(each.value.icon_path, each.value.path)
  icon_index                   = try(each.value.icon_index, 0)
}

resource "azurerm_role_assignment" "avd_users" {
  for_each = local.host_pools

  scope                = azurerm_virtual_desktop_application_group.this[each.key].id
  role_definition_name = "Desktop Virtualization User"
  principal_id         = data.azuread_group.avd_users[each.key].object_id
}

resource "azurerm_role_assignment" "avd_users_vm_login" {
  for_each = local.host_pools

  scope                = data.azurerm_resource_group.compute[each.key].id
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
  resource_group_name = data.azurerm_resource_group.compute[each.key].name
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
  parent_id = data.azurerm_resource_group.compute[each.key].id
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
