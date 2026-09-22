# 06-storage-example — npd environment
active_directory_domain_name = "int.local"
active_directory_domain_guid = "fea35cd0-3ec6-4c7d-8b99-1073c5d00d19"

fslogix_storage_account_name                 = "stavditmnpd001"
fslogix_managed_identity_name                = "mi-avd-storage-itm-npd"
fslogix_file_private_endpoint_name           = "pe-avd-files-itm-npd"
fslogix_file_private_service_connection_name = "psc-files-itm-npd"
fslogix_file_private_dns_zone_group_name     = "dns-file-itm-npd"
fslogix_share_name                           = "fslogix"
fslogix_share_quota_gb                       = 100
fslogix_users_group                          = "avd_users_cloud"
fslogix_identity_auth_directory_service      = null # set to "AADKERB" when exempt from Entra App Policies credential lifesycle

general_storage_account_name                 = "stgenitmnpd001"
general_managed_identity_name                = "mi-storage-general-itm-npd"
general_blob_private_endpoint_name           = "pe-general1-blob-itm-npd"
general_blob_private_service_connection_name = "psc-general1-blob-itm-npd"
general_blob_private_dns_zone_group_name     = "dns-general1-blob-itm-npd"
