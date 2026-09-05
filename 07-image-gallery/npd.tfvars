aib_rg                          = "rg-imagebuilder"
location                        = "australiaeast"
rg_network                      = "rg-itm-network-npd"
vnet_name                       = "vnet-itm-vnet-npd"
publisher                       = "MicrosoftWindowsServer"
offer                           = "WindowsServer"
sku                             = "2022-datacenter-azure-edition"
compute_gallery_name            = "avd_image_gallery"
gallery_image_definition_name   = "winserver2022-002"
aib_user_assigned_identity_name = "id-aib-imagebuilder-npd"
aib_role_definition_name        = "role-aib-imagebuilder-npd"

tags = {
  project = "Custom-Image-Builder-Demo"
}
