variable "avdLocation" {
  type        = string
  description = "Azure region"
}

variable "prefix" {
  type        = string
  description = "Short prefix, max 4 chars, lowercase"
}

variable "environment" {
  type        = string
  description = "dev | test | prod"
}

variable "spoke_subscription_id" {
  type        = string
  description = "Spoke subscription ID"
}

variable "rg_compute_name" {
  type        = string
  description = "Compute RG name (from module 01: rg_compute_name)"
}

variable "subnet_id" {
  type        = string
  description = "Session host subnet ID (from module 02: subnet_id)"
}

variable "rdsh_count" {
  type        = number
  default     = 2
  description = "Number of session host VMs"
}

variable "vm_size" {
  type        = string
  default     = "Standard_D2s_v5"
  description = "VM SKU"
}

variable "local_admin_username" {
  type        = string
  default     = "avdadmin"
  description = "Local admin username"
}
variable "vm_password" {
  type        = string
  sensitive   = true
  description = "Local admin password (from module 04: vm_password_value) — use pipeline secret variable"
}
variable "hostpool_name" {
  type        = string
  default     = null
  nullable    = true
  description = "Optional override for host pool name. If not set, read from 05-avd-hostpool state."
}
variable "registration_token" {
  type        = string
  sensitive   = true
  default     = null
  nullable    = true
  description = "Optional override for AVD registration token. If not set, read automatically from 05-avd-hostpool state."
}
variable "publisher" {
  type        = string
  default     = "MicrosoftWindowsDesktop"
  description = "Marketplace image publisher"
}

variable "offer" {
  type        = string
  default     = "windows-11"
  description = "Marketplace image offer"
}

variable "sku" {
  type        = string
  default     = "win11-24h2-avd"
  description = "Marketplace image SKU"
}

variable "image_version" {
  type        = string
  default     = "latest"
  description = "Marketplace image version"
}

# ── Per-app variables ────────────────────────────────────────────────────
variable "app_name" {
  type        = string
  description = "Short application identifier matching the app_name used in module 05 (e.g. 'finance'). Included in VM names so each app gets its own set of session hosts."
  validation {
    condition     = can(regex("^[a-z0-9]{1,8}$", var.app_name))
    error_message = "app_name must be 1-8 lowercase alphanumeric characters."
  }
}

variable "hostpool_state_path" {
  type        = string
  default     = null
  nullable    = true
  description = "Absolute or relative path to the 05-avd-hostpool terraform.tfstate for this app. Defaults to ../05-avd-hostpool/terraform.tfstate. Override when each app has its own state file (e.g. ../05-avd-hostpool-finance/terraform.tfstate)."
}

# ── FSLogix variables ────────────────────────────────────────────────
variable "fslogix_storage_account_name" {
  type        = string
  description = "FSLogix storage account name (from module 06: storage_account_name). The session host profile UNC path is built as \\\\<name>.file.core.windows.net\\<share>."
}

variable "fslogix_share_name" {
  type        = string
  default     = "fslogix"
  description = "Azure Files share name for FSLogix profiles (from module 06: fslogix_share_name). Defaults to 'fslogix'."
}

variable "fslogix_profile_size_mb" {
  type        = number
  default     = 30720
  description = "Maximum size of each FSLogix profile VHD in MB. Disk grows dynamically (IsDynamic=1). Default 30 GB (30720 MB)."
}
