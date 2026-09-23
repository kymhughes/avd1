locals {
  vm_contributor_role_definition = "/providers/Microsoft.Authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c"
}

resource "azurerm_policy_definition" "deploy_ama_windows" {
  name         = "deploy-ama-windows-${var.environment}"
  policy_type  = "Custom"
  mode         = "Indexed"
  display_name = "Deploy Azure Monitor Agent to Windows VMs"
  description  = "Deploys the Azure Monitor Windows Agent VM extension to Windows virtual machines."

  metadata = jsonencode({
    category = "Monitoring"
  })

  parameters = jsonencode({
    effect = {
      type          = "String"
      defaultValue  = "DeployIfNotExists"
      allowedValues = ["DeployIfNotExists", "Disabled"]
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
          field = "tags['${var.session_host_vm_tag_name}']"
          like  = var.session_host_vm_tag_like
        }
      ]
    }
    then = {
      effect = "[parameters('effect')]"
      details = {
        type            = "Microsoft.Compute/virtualMachines/extensions"
        evaluationDelay = "AfterProvisioningSuccess"
        existenceCondition = {
          allOf = [
            {
              field  = "Microsoft.Compute/virtualMachines/extensions/publisher"
              equals = "Microsoft.Azure.Monitor"
            },
            {
              field  = "Microsoft.Compute/virtualMachines/extensions/type"
              equals = "AzureMonitorWindowsAgent"
            },
            {
              field  = "Microsoft.Compute/virtualMachines/extensions/provisioningState"
              equals = "Succeeded"
            }
          ]
        }
        roleDefinitionIds = [
          local.vm_contributor_role_definition
        ]
        deployment = {
          properties = {
            mode = "incremental"
            template = {
              "$schema"      = "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#"
              contentVersion = "1.0.0.0"
              parameters = {
                vmName = {
                  type = "String"
                }
                location = {
                  type = "String"
                }
              }
              resources = [
                {
                  type       = "Microsoft.Compute/virtualMachines/extensions"
                  apiVersion = "2023-09-01"
                  name       = "[concat(parameters('vmName'), '/AzureMonitorWindowsAgent')]"
                  location   = "[parameters('location')]"
                  properties = {
                    publisher               = "Microsoft.Azure.Monitor"
                    type                    = "AzureMonitorWindowsAgent"
                    typeHandlerVersion      = "1.0"
                    autoUpgradeMinorVersion = true
                    enableAutomaticUpgrade  = true
                    suppressFailures        = false
                    settings                = {}
                    protectedSettings       = {}
                  }
                }
              ]
            }
            parameters = {
              vmName = {
                value = "[field('name')]"
              }
              location = {
                value = "[field('location')]"
              }
            }
          }
        }
      }
    }
  })
}

resource "azurerm_subscription_policy_assignment" "deploy_ama_windows" {
  name                 = "deploy-ama-windows-${var.environment}"
  display_name         = "Deploy Azure Monitor Agent to Windows VMs"
  policy_definition_id = azurerm_policy_definition.deploy_ama_windows.id
  subscription_id      = local.diagnostic_policy_scope
  location             = var.avdLocation
  description          = "Installs Azure Monitor Agent on virtual machines so DCR-based guest telemetry can be collected."

  identity {
    type = "SystemAssigned"
  }

  parameters = jsonencode({
    effect = {
      value = var.enable_ama_policies ? "DeployIfNotExists" : "Disabled"
    }
  })
}

resource "azurerm_role_assignment" "deploy_ama_windows_vm_contributor" {
  scope                = local.diagnostic_policy_scope
  role_definition_name = "Virtual Machine Contributor"
  principal_id         = azurerm_subscription_policy_assignment.deploy_ama_windows.identity[0].principal_id
}

resource "azurerm_policy_definition" "associate_session_host_dcr" {
  name         = "associate-session-host-dcr-${var.environment}"
  policy_type  = "Custom"
  mode         = "Indexed"
  display_name = "Associate AVD session host DCR to VMs"
  description  = "Associates the AVD session host Data Collection Rule to virtual machines."

  metadata = jsonencode({
    category = "Monitoring"
  })

  parameters = jsonencode({
    effect = {
      type          = "String"
      defaultValue  = "DeployIfNotExists"
      allowedValues = ["DeployIfNotExists", "Disabled"]
    }
    dataCollectionRuleId = {
      type = "String"
    }
    associationName = {
      type         = "String"
      defaultValue = var.data_collection_rule_association_name
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
          field = "tags['${var.session_host_vm_tag_name}']"
          like  = var.session_host_vm_tag_like
        }
      ]
    }
    then = {
      effect = "[parameters('effect')]"
      details = {
        type            = "Microsoft.Insights/dataCollectionRuleAssociations"
        name            = "[parameters('associationName')]"
        evaluationDelay = "AfterProvisioningSuccess"
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
                associationName = {
                  type = "String"
                }
                dataCollectionRuleId = {
                  type = "String"
                }
              }
              resources = [
                {
                  type       = "Microsoft.Insights/dataCollectionRuleAssociations"
                  apiVersion = "2022-06-01"
                  name       = "[parameters('associationName')]"
                  scope      = "[parameters('resourceId')]"
                  properties = {
                    dataCollectionRuleId = "[parameters('dataCollectionRuleId')]"
                  }
                }
              ]
            }
            parameters = {
              resourceId = {
                value = "[field('id')]"
              }
              associationName = {
                value = "[parameters('associationName')]"
              }
              dataCollectionRuleId = {
                value = "[parameters('dataCollectionRuleId')]"
              }
            }
          }
        }
      }
    }
  })
}

resource "azurerm_subscription_policy_assignment" "associate_session_host_dcr" {
  name                 = "associate-dcr-${var.environment}"
  display_name         = "Associate AVD session host DCR to VMs"
  policy_definition_id = azurerm_policy_definition.associate_session_host_dcr.id
  subscription_id      = local.diagnostic_policy_scope
  location             = var.avdLocation
  description          = "Associates virtual machines to ${var.data_collection_rule_name}."

  identity {
    type = "SystemAssigned"
  }

  parameters = jsonencode({
    effect = {
      value = var.enable_ama_policies ? "DeployIfNotExists" : "Disabled"
    }
    dataCollectionRuleId = {
      value = azurerm_monitor_data_collection_rule.session_hosts.id
    }
    associationName = {
      value = var.data_collection_rule_association_name
    }
  })
}

resource "azurerm_role_assignment" "associate_session_host_dcr_monitoring_contributor" {
  scope                = local.diagnostic_policy_scope
  role_definition_name = "Monitoring Contributor"
  principal_id         = azurerm_subscription_policy_assignment.associate_session_host_dcr.identity[0].principal_id
}

resource "azurerm_subscription_policy_remediation" "deploy_ama_windows" {
  count = var.enable_ama_policy_remediation ? 1 : 0

  name                    = "remediate-deploy-ama-windows-${var.environment}"
  subscription_id         = local.diagnostic_policy_scope
  policy_assignment_id    = azurerm_subscription_policy_assignment.deploy_ama_windows.id
  resource_discovery_mode = "ReEvaluateCompliance"

  depends_on = [
    azurerm_role_assignment.deploy_ama_windows_vm_contributor
  ]
}

resource "azurerm_subscription_policy_remediation" "associate_session_host_dcr" {
  count = var.enable_ama_policy_remediation ? 1 : 0

  name                    = "remediate-associate-dcr-${var.environment}"
  subscription_id         = local.diagnostic_policy_scope
  policy_assignment_id    = azurerm_subscription_policy_assignment.associate_session_host_dcr.id
  resource_discovery_mode = "ReEvaluateCompliance"

  depends_on = [
    azurerm_role_assignment.associate_session_host_dcr_monitoring_contributor
  ]
}
