# 07-session-hosts — dev environment
# vm_password — PIPELINE SECRET VARIABLE, never in tfvars
# Run once per app: set app_name to match the app_name used in module 05
avdLocation           = "australiaeast"
prefix                = "dev1"
environment           = "dev"
app_name              = "finance"
spoke_subscription_id = "05e200dc-cec4-4234-8142-d2fe12e9d48f"
rdsh_count            = 1
vm_size               = "Standard_D2s_v5"
local_admin_username  = "avdadmin"
publisher             = "MicrosoftWindowsDesktop"
offer                 = "windows-11"
sku                   = "win11-24h2-avd"
image_version         = "latest"
# hostpool_state_path — uncomment to override for per-app state files
# hostpool_state_path = "../05-avd-hostpool-finance/terraform.tfstate"

# From module 01 outputs (deterministic names)
rg_compute_name = "rg-avd-dev1-dev-australiaeast-pool-compute"

# From module 02 outputs (deterministic names)
subnet_id = "/subscriptions/05e200dc-cec4-4234-8142-d2fe12e9d48f/resourceGroups/rg-avd-austr-dev1-network/providers/Microsoft.Network/virtualNetworks/vnet-avd-austr-dev1-001/subnets/snet-avd-hp-austr-dev1-001"

# From module 06 outputs — update after module 06 runs
fslogix_storage_account_name = "stavddev1yhj6"
fslogix_share_name           = "fslogix"
fslogix_profile_size_mb      = 30720
