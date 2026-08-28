resource_group_name = "rg-avd-session-host-demo"
subscription_id     = "e4ea360b-bf76-47bc-bb09-81bd23faad9e"
location            = "australiaeast"
name_prefix         = "avd-demo"
vm_name             = "avd-sh-01"
vm_size             = "Standard_D4s_v5"

existing_vnet_resource_group_name = "rg-itm-network-npd"
existing_vnet_name                = "vnet-itm-vnet-npd"
existing_subnet_name              = "snet-ib2-tools"

admin_username = "avdadmin"
admin_password = "P@ssw0rd123123"

# Paste a valid AVD host pool registration token to register this VM as a session host.
# Leave empty if you only want to stage prerequisites first.
avd_registration_token = ""

install_fslogix = false

# Example for Azure Files profiles:
# fslogix_profile_container_unc_path = "\\\\mystorageaccount.file.core.windows.net\\profiles"
fslogix_profile_container_unc_path = ""

# Optional custom app bootstrap from blob storage. Use a short-lived SAS URL.
# custom_app_blob_url           = "https://mystorage.blob.core.windows.net/installers/app.msi?<sas>"
# custom_app_file_name          = "app.msi"
# custom_app_install_command    = "msiexec.exe /i {file} /qn /norestart"
# custom_app_expected_sha256    = "ABCDEF..."

# custom_app_blob_url        = ""
# custom_app_file_name       = "custom-app-installer"
# custom_app_install_command = ""

reboot_after_bootstrap = true
