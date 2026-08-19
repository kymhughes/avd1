# 07-session-hosts — prod environment
# vm_password — PIPELINE SECRET VARIABLE, never in tfvars
# Run once per app: set app_name to match the app_name used in module 05
app_name             = "ops"
rdsh_count           = 2
vm_size              = "Standard_D2s_v5"
local_admin_username = "avdadmin"
publisher            = "MicrosoftWindowsDesktop"
offer                = "windows-11"
sku                  = "win11-24h2-avd"
image_version        = "latest"

# From module 01 outputs (deterministic)
rg_compute_name = "rg-avd-poc1-prod-australiaeast-pool-compute"

# From module 02 outputs (deterministic)
subnet_id = "/subscriptions/05e200dc-cec4-4234-8142-d2fe12e9d48f/resourceGroups/rg-avd-austr-poc1-network/providers/Microsoft.Network/virtualNetworks/vnet-avd-austr-poc1-001/subnets/snet-avd-hp-austr-poc1-001"

# From module 06 outputs — update after module 06 runs
fslogix_storage_account_name = "stavdpoc1t77j"
fslogix_share_name           = "fslogix"
fslogix_profile_size_mb      = 30720
