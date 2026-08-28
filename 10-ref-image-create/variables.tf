variable "location" {
  description = "Azure region for all resources."
  type        = string
  default     = "australiaeast"
}

variable "subscription_id" {
  description = "Azure subscription ID. Required by recent AzureRM provider versions unless ARM_SUBSCRIPTION_ID is set."
  type        = string
  default     = null
}

variable "resource_group_name" {
  description = "Resource group name to create for the VM and related compute resources."
  type        = string
}

variable "name_prefix" {
  description = "Prefix used for resource names."
  type        = string
  default     = "avd-sh"
}

variable "tags" {
  description = "Tags to apply to all supported resources."
  type        = map(string)
  default = {
    workload = "avd-session-host"
  }
}

variable "vm_name" {
  description = "Windows VM name."
  type        = string
  default     = "avd-sh-01"
}

variable "existing_vnet_name" {
  description = "Name of the existing virtual network that contains the session host subnet."
  type        = string
}

variable "existing_vnet_resource_group_name" {
  description = "Resource group containing the existing virtual network."
  type        = string
}

variable "existing_subnet_name" {
  description = "Name of the existing subnet for the session host NIC."
  type        = string
}

variable "vm_size" {
  description = "Azure VM size."
  type        = string
  default     = "Standard_D4s_v5"
}

variable "admin_username" {
  description = "Local administrator username."
  type        = string
  default     = "avdadmin"
}

variable "admin_password" {
  description = "Local administrator password."
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.admin_password) >= 14
    error_message = "admin_password must be at least 14 characters."
  }
}

variable "source_image_reference" {
  description = "Marketplace image for Windows Server 2022."
  type = object({
    publisher = string
    offer     = string
    sku       = string
    version   = string
  })
  default = {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-azure-edition"
    version   = "latest"
  }
}

variable "os_disk_type" {
  description = "Managed disk type for the OS disk."
  type        = string
  default     = "Premium_LRS"
}

variable "avd_registration_token" {
  description = "AVD host pool registration token. Leave empty to install prerequisites without registering the VM."
  type        = string
  default     = ""
  sensitive   = true
}

variable "install_fslogix" {
  description = "Install FSLogix and configure profile container registry settings."
  type        = bool
  default     = true
}

variable "fslogix_profile_container_unc_path" {
  description = "UNC path for FSLogix profile containers, for example \\\\storageaccount.file.core.windows.net\\profiles. Leave empty to install FSLogix without enabling profiles."
  type        = string
  default     = ""
}

variable "custom_app_blob_url" {
  description = "HTTPS blob URL, typically with SAS, for the custom application installer. Leave empty to skip."
  type        = string
  default     = ""
  sensitive   = true
}

variable "custom_app_file_name" {
  description = "Local filename to use for the downloaded custom app installer."
  type        = string
  default     = "custom-app-installer"
}

variable "custom_app_install_command" {
  description = "Command used to install the custom app. Use {file} as a placeholder for the downloaded installer path."
  type        = string
  default     = ""
  sensitive   = true
}

variable "custom_app_expected_sha256" {
  description = "Optional SHA256 hash for the custom app installer."
  type        = string
  default     = ""
}

variable "reboot_after_bootstrap" {
  description = "Reboot after bootstrap completes, or sooner if Windows Update requires it."
  type        = bool
  default     = true
}
