aib_region                       = "australiaeast"
aib_rg                           = "rg-imagebuilder"
aib_subnet_id                    = "/subscriptions/e4ea360b-bf76-47bc-bb09-81bd23faad9e/resourceGroups/rg-itm-network-npd/providers/Microsoft.Network/virtualNetworks/vnet-itm-vnet-npd/subnets/snet-ib1-vms"
aib_container_instance_subnet_id = "/subscriptions/e4ea360b-bf76-47bc-bb09-81bd23faad9e/resourceGroups/rg-itm-network-npd/providers/Microsoft.Network/virtualNetworks/vnet-itm-vnet-npd/subnets/snet-ib2-tools"
image_replication_regions        = ["australiaeast"]
location                         = "australiaeast"
offer                            = "WindowsServer"
publisher                        = "MicrosoftWindowsServer"
sku                              = "2022-datacenter-g2"
prefix                           = "AIBdemo"
optimization_script_uri          = "https://raw.githubusercontent.com/Azure/avdaccelerator/main/workload/scripts/Optimize_OS_for_AVD.ps1"
rg_network                       = "rg-itm-network-npd"
vnet_name                        = "vnet-itm-vnet-npd"
tags = {
  project = "Custom-Image-Builder-Demo"
}
