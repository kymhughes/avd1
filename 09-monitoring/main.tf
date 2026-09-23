# Creates the Log Analytics workspace used for AVD monitoring and diagnostics.
# The monitoring resource group must already exist and is supplied per
# environment by this folder's npd/uat/prd tfvars files.

module "avm_res_operationalinsights_workspace" {
  source  = "Azure/avm-res-operationalinsights-workspace/azurerm"
  version = "0.1.3"

  name                = var.log_analytics_workspace_name
  resource_group_name = var.rg_monitoring_name
  location            = var.avdLocation
  tags                = var.tags
  enable_telemetry    = var.enable_telemetry
}
