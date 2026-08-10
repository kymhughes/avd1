# 06-storage — prod environment
avdLocation             = "australiaeast"
prefix                  = "poc1"
environment             = "prod"
spoke_subscription_id   = "05e200dc-cec4-4234-8142-d2fe12e9d48f"
hub_subscription_id     = "aa99492d-2efe-4d6e-995c-ec734bd0cbb3"
hub_dns_zone_rg         = "rg-privatedns"
fslogix_share_quota_gb  = 100

# From module 01 outputs (deterministic)
rg_storage_name         = "rg-avd-poc1-prod-australiaeast-storage"

# From module 02 outputs (deterministic)
pesubnet_id             = "/subscriptions/05e200dc-cec4-4234-8142-d2fe12e9d48f/resourceGroups/rg-avd-austr-poc1-network/providers/Microsoft.Network/virtualNetworks/vnet-avd-austr-poc1-001/subnets/snet-avd-pe-austr-poc1-001"
spoke_vnet_id           = "/subscriptions/05e200dc-cec4-4234-8142-d2fe12e9d48f/resourceGroups/rg-avd-austr-poc1-network/providers/Microsoft.Network/virtualNetworks/vnet-avd-austr-poc1-001"
