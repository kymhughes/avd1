locals {
  diagnostic_policy_scope                = "/subscriptions/${var.spoke_subscription_id}"
  monitoring_contributor_role_definition = "/providers/Microsoft.Authorization/roleDefinitions/749f88d5-cbae-40b8-bcfc-e573ddc772fa"

  diagnostic_policy_resources = {
    for key, config in var.diagnostic_policy_resource_types : key => {
      name           = "diag-${replace(key, "_", "-")}"
      assignment     = "diag-${replace(key, "_", "-")}-${var.environment}"
      display_name   = config.display_name
      resource_type  = config.resource_type
      enable_logs    = try(config.enable_logs, true)
      enable_metrics = try(config.enable_metrics, true)
    }
  }
}

resource "azurerm_policy_definition" "diagnostic_settings" {
  for_each = local.diagnostic_policy_resources

  name         = each.value.name
  policy_type  = "Custom"
  mode         = "Indexed"
  display_name = "Deploy diagnostic settings for ${each.value.display_name}"
  description  = "Deploys Azure Monitor diagnostic settings for ${each.value.resource_type} resources to the AVD Log Analytics workspace."

  metadata = jsonencode({
    category = "Monitoring"
  })

  parameters = jsonencode({
    effect = {
      type          = "String"
      defaultValue  = "DeployIfNotExists"
      allowedValues = ["DeployIfNotExists", "Disabled"]
    }
    logAnalyticsWorkspaceId = {
      type = "String"
    }
    diagnosticSettingName = {
      type         = "String"
      defaultValue = var.diagnostic_setting_name
    }
  })

  policy_rule = jsonencode({
    if = {
      field  = "type"
      equals = each.value.resource_type
    }
    then = {
      effect = "[parameters('effect')]"
      details = {
        type            = "Microsoft.Insights/diagnosticSettings"
        evaluationDelay = "AfterProvisioningSuccess"
        existenceCondition = {
          field  = "Microsoft.Insights/diagnosticSettings/workspaceId"
          equals = "[parameters('logAnalyticsWorkspaceId')]"
        }
        roleDefinitionIds = [
          local.monitoring_contributor_role_definition
        ]
        deployment = {
          properties = {
            mode = "incremental"
            template = {
              "$schema"      = "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#"
              contentVersion = "1.0.0.0"
              parameters = {
                resourceId = {
                  type = "String"
                }
                diagnosticSettingName = {
                  type = "String"
                }
                logAnalyticsWorkspaceId = {
                  type = "String"
                }
              }
              resources = [
                {
                  type       = "Microsoft.Insights/diagnosticSettings"
                  apiVersion = "2021-05-01-preview"
                  name       = "[parameters('diagnosticSettingName')]"
                  scope      = "[parameters('resourceId')]"
                  properties = merge(
                    {
                      workspaceId = "[parameters('logAnalyticsWorkspaceId')]"
                    },
                    each.value.enable_logs ? {
                      logs = [
                        {
                          categoryGroup = "allLogs"
                          enabled       = true
                        }
                      ]
                    } : {},
                    each.value.enable_metrics ? {
                      metrics = [
                        {
                          category = "AllMetrics"
                          enabled  = true
                        }
                      ]
                    } : {}
                  )
                }
              ]
            }
            parameters = {
              resourceId = {
                value = "[field('id')]"
              }
              diagnosticSettingName = {
                value = "[parameters('diagnosticSettingName')]"
              }
              logAnalyticsWorkspaceId = {
                value = "[parameters('logAnalyticsWorkspaceId')]"
              }
            }
          }
        }
      }
    }
  })
}

resource "azurerm_subscription_policy_assignment" "diagnostic_settings" {
  for_each = local.diagnostic_policy_resources

  name                 = each.value.assignment
  display_name         = "Deploy diagnostics for ${each.value.display_name}"
  policy_definition_id = azurerm_policy_definition.diagnostic_settings[each.key].id
  subscription_id      = local.diagnostic_policy_scope
  location             = var.avdLocation
  description          = "Deploys diagnostic settings for ${each.value.resource_type} to ${var.log_analytics_workspace_name}."

  identity {
    type = "SystemAssigned"
  }

  parameters = jsonencode({
    effect = {
      value = var.enable_diagnostic_policies ? "DeployIfNotExists" : "Disabled"
    }
    logAnalyticsWorkspaceId = {
      value = module.avm_res_operationalinsights_workspace.resource.id
    }
    diagnosticSettingName = {
      value = var.diagnostic_setting_name
    }
  })
}

resource "azurerm_role_assignment" "diagnostic_policy_monitoring_contributor" {
  for_each = local.diagnostic_policy_resources

  scope                = local.diagnostic_policy_scope
  role_definition_name = "Monitoring Contributor"
  principal_id         = azurerm_subscription_policy_assignment.diagnostic_settings[each.key].identity[0].principal_id
}

resource "azurerm_subscription_policy_remediation" "diagnostic_settings" {
  for_each = var.enable_diagnostic_policy_remediation ? local.diagnostic_policy_resources : {}

  name                    = "remediate-${each.value.assignment}"
  subscription_id         = local.diagnostic_policy_scope
  policy_assignment_id    = azurerm_subscription_policy_assignment.diagnostic_settings[each.key].id
  resource_discovery_mode = "ReEvaluateCompliance"

  depends_on = [
    azurerm_role_assignment.diagnostic_policy_monitoring_contributor
  ]
}
