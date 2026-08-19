# 07-session-hosts — nonprod environment
# vm_password, registration_token — PIPELINE SECRET VARIABLES, never in tfvars
rdsh_count           = 2
vm_size              = "Standard_D2s_v5"
local_admin_username = "avdadmin"
publisher            = "MicrosoftWindowsDesktop"
offer                = "windows-11"
sku                  = "win11-24h2-avd"
image_version        = "latest"

# From module 01 outputs
rg_compute_name = "rg-avd-nprd-nonprod-australiaeast-pool-compute" # replace with actual value

# From module 02 outputs
subnet_id = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/rg-avd-austr-nprd-network/providers/Microsoft.Network/virtualNetworks/vnet-avd-austr-nprd-001/subnets/snet-avd-hp-austr-nprd-001" # replace with actual value
