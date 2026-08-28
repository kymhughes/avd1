# Azure Server 2022 AVD Session Host VM

This Terraform deploys a Windows Server 2022 Azure VM and prepares it for Azure Virtual Desktop session-host use.

It includes:

1. A resource group, NIC, and Windows Server 2022 VM attached to an existing subnet.
2. Azure platform patch orchestration via `AutomaticByPlatform`.
3. An initial Windows Update pass during bootstrap.
4. FSLogix installation and optional profile-container registry configuration.
5. Optional AVD agent and bootloader installation using a host pool registration token.
6. Optional custom application download and installation from a blob URL, usually a SAS-protected installer.

## Usage

```powershell
cd "C:\Users\kymh\OneDrive\Documents\Microsoft Scout\avd-session-host-vm"
copy terraform.tfvars.example terraform.tfvars
notepad terraform.tfvars
terraform init
terraform plan
terraform apply
```

## Important variables

| Variable | Purpose |
| --- | --- |
| `subscription_id` | Azure subscription to deploy into. You can also set `ARM_SUBSCRIPTION_ID` instead. |
| `existing_vnet_resource_group_name` | Resource group containing the existing VNet. |
| `existing_vnet_name` | Existing VNet name. |
| `existing_subnet_name` | Existing subnet name for the session host NIC. |
| `admin_password` | Local administrator password. Store securely and do not commit real values. |
| `avd_registration_token` | Host pool registration token. If empty, the VM is prepared but not registered to AVD. |
| `fslogix_profile_container_unc_path` | UNC path such as `\\storageaccount.file.core.windows.net\profiles`. If empty, FSLogix installs but profile containers are not enabled with a location. |
| `custom_app_blob_url` | Blob installer URL, typically including a short-lived SAS token. |
| `custom_app_install_command` | Installer command. Use `{file}` where the downloaded installer path should be inserted. |
| `custom_app_expected_sha256` | Optional integrity check for the downloaded custom app installer. |

## Custom app examples

MSI:

```hcl
custom_app_blob_url        = "https://mystorage.blob.core.windows.net/installers/app.msi?<sas>"
custom_app_file_name       = "app.msi"
custom_app_install_command = "msiexec.exe /i {file} /qn /norestart"
custom_app_expected_sha256 = "ABCDEF..."
```

EXE:

```hcl
custom_app_blob_url        = "https://mystorage.blob.core.windows.net/installers/setup.exe?<sas>"
custom_app_file_name       = "setup.exe"
custom_app_install_command = "{file} /quiet /norestart"
```

## Production notes

This example does not create or attach an NSG and does not create a public IP address. Apply subnet security, routing, DNS, private connectivity, Azure Bastion, or JIT access through your existing network design. Domain join, Entra ID join, Azure Files identity/RBAC, host pool creation, and image management are environment-specific and should be layered in according to your AVD design.
