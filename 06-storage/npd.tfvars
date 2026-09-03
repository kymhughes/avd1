# 06-storage — npd environment
rg_storage_name = "rg-service-objects-npd"
rg_network      = "rg-itm-network-npd"
vnet_name       = "vnet-itm-vnet-npd"
pesubnet_files  = "snet-general-pe"

# Optional hybrid Microsoft Entra Kerberos AD metadata, applied to all storage accounts.
active_directory_domain_name = "int.local"
active_directory_domain_guid = "fea35cd0-3ec6-4c7d-8b99-1073c5d00d19"

storage_accounts = {
  fslogix = {
    name                  = "stavditmnpd001"
    managed_identity_name = "mi-avd-storage-itm-npd"
    kind                  = "FileStorage"
    sku_name              = "Premium_LRS"
    # identity_auth_directory_service = "AADKERB"  # set to null to disable AAD Kerberos authentication and exempt in entra policy
    # identity_auth_directory_service = null
    private_endpoint_name           = "pe-avd-files-itm-npd"
    private_service_connection_name = "psc-files-itm-npd"
    private_dns_zone_group_name     = "dns-file-itm-npd"
    private_dns_vnet_link_name      = "link-files-itm-npd"
    shares = {
      fslogix = {
        name     = "fslogix"
        quota_gb = 100
        smb_role_assignments = {
          avd_users = {
            group_name           = "avd_users_cloud"
            role_definition_name = "Storage File Data SMB Share Contributor"
          }
        }
        # Separate ACL administrators from normal users.
        # smb_admin_groups = ["avd_storage_acl_admins"]
      }
    }
  }

  general1 = {
    name                  = "stgenitmnpd001"
    managed_identity_name = "mi-storage-general1-itm-npd"
    kind                  = "FileStorage"
    sku_name              = "StandardV2_LRS"
    #identity_auth_directory_service = "AADKERB"
    private_endpoint_name           = "pe-general1-files-itm-npd"
    private_service_connection_name = "psc-general1-files-itm-npd"
    private_dns_zone_group_name     = "dns-general1-file-itm-npd"
    private_dns_vnet_link_name      = "link-general1-files-itm-npd"
    shares = {
      data = {
        name     = "data"
        quota_gb = 100
        smb_role_assignments = {
          avd_users = {
            group_name           = "avd_users_cloud"
            role_definition_name = "Storage File Data SMB Share Contributor"
          }
        }
      }
    }
  }
  general2 = {
    name                  = "stgenitmnpd002"
    managed_identity_name = "mi-storage-general2-itm-npd"
    kind                  = "StorageV2"
    sku_name              = "Standard_LRS"
    #identity_auth_directory_service = "AADKERB"
    private_endpoint_name                = "pe-general2-files-itm-npd"
    private_service_connection_name      = "psc-general2-files-itm-npd"
    private_dns_zone_group_name          = "dns-general2-file-itm-npd"
    private_dns_vnet_link_name           = "link-general2-files-itm-npd"
    blob_private_endpoint_enabled        = true
    blob_private_endpoint_name           = "pe-general2-blob-itm-npd"
    blob_private_service_connection_name = "psc-general2-blob-itm-npd"
    blob_private_dns_zone_group_name     = "dns-general2-blob-itm-npd"
    shares = {
      shared = {
        name        = "shared"
        quota_gb    = 100
        rbac_groups = ["avd_users_cloud"]
      }
    }
  }

}
