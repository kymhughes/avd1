# 06-storage — npd environment
rg_storage_name = "rg-service-objects-npd"
rg_network      = "rg-itm-network-npd"
vnet_name       = "vnet-itm-vnet-npd"
pesubnet_files  = "snet-general-pe"

storage_accounts = {
  fslogix = {
    name                            = "stavditmnpd001"
    managed_identity_name           = "mi-avd-storage-itm-npd"
    kind                            = "FileStorage"
    sku_name                        = "Premium_LRS"
    identity_auth_directory_service = "AADKERB"
    private_endpoint_name           = "pe-avd-files-itm-npd"
    private_service_connection_name = "psc-files-itm-npd"
    private_dns_zone_group_name     = "dns-file-itm-npd"
    private_dns_vnet_link_name      = "link-files-itm-npd"
    shares = {
      fslogix = {
        name        = "fslogix"
        quota_gb    = 100
        rbac_groups = ["avd_users_cloud"]
      }
    }
  }

  general1 = {
    name                            = "stgenitmnpd001"
    managed_identity_name           = "mi-storage-general1-itm-npd"
    kind                            = "StorageV2"
    sku_name                        = "Standard_LRS"
    identity_auth_directory_service = "AADKERB"
    private_endpoint_name           = "pe-general1-files-itm-npd"
    private_service_connection_name = "psc-general1-files-itm-npd"
    private_dns_zone_group_name     = "dns-general1-file-itm-npd"
    private_dns_vnet_link_name      = "link-general1-files-itm-npd"
    shares = {
      data = {
        name        = "data"
        quota_gb    = 100
        rbac_groups = ["avd_users_cloud"]
      }
    }
  }

  general2 = {
    name                            = "stgenitmnpd002"
    managed_identity_name           = "mi-storage-general2-itm-npd"
    kind                            = "StorageV2"
    sku_name                        = "Standard_LRS"
    identity_auth_directory_service = "AADKERB"
    private_endpoint_name           = "pe-general2-files-itm-npd"
    private_service_connection_name = "psc-general2-files-itm-npd"
    private_dns_zone_group_name     = "dns-general2-file-itm-npd"
    private_dns_vnet_link_name      = "link-general2-files-itm-npd"
    shares = {
      shared = {
        name        = "shared"
        quota_gb    = 100
        rbac_groups = ["avd_users_cloud"]
      }
    }
  }
}
