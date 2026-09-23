# Creates the monitoring resource group and Log Analytics workspace used for
# AVD monitoring and diagnostics.

resource "azurerm_resource_group" "monitoring" {
  name     = var.rg_monitoring_name
  location = var.avdLocation
  tags     = var.tags
}

module "avm_res_operationalinsights_workspace" {
  source  = "Azure/avm-res-operationalinsights-workspace/azurerm"
  version = "0.1.3"

  name                = var.log_analytics_workspace_name
  resource_group_name = azurerm_resource_group.monitoring.name
  location            = var.avdLocation
  tags                = var.tags
  enable_telemetry    = var.enable_telemetry
}
