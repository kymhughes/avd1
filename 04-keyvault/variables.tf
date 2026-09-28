variable "avdLocation" {
  type        = string
  description = "Azure region for Key Vault."
}

variable "tenant_id" {
  type        = string
  description = "Azure tenant ID."
}

variable "spoke_subscription_id" {
  type        = string
  description = "Azure subscription ID for the AVD spoke workload."
}

variable "hub_subscription_id" {
  type        = string
  description = "Azure subscription ID for the hub virtual network."
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to supported resources."
  default     = {}
}

variable "rg_so" {
  type        = string
  description = "Service objects resource group name."
}

variable "keyvault_name" {
  type        = string
  description = "Key Vault name."
}

variable "vm_local_admin_username" {
  type        = string
  description = "Local administrator username for AVD session hosts."
  default     = "localadmin"
}

variable "vm_local_admin_username_secret_name" {
  type        = string
  description = "Key Vault secret name for the AVD session host local administrator username."
  default     = "vm-local-admin-username"
}

variable "vm_local_admin_password_secret_name" {
  type        = string
  description = "Key Vault secret name for the AVD session host local administrator password."
  default     = "local-password"
}

variable "cmk_key_name" {
  type        = string
  description = "Key Vault key name used as the customer-managed key for AVD managed disks."
  default     = "avd-cmk-key"
}

variable "cmk_key_size" {
  type        = number
  description = "RSA key size for the customer-managed key."
  default     = 4096
}

variable "cmk_key_rotation_time_after_creation" {
  type        = string
  description = "ISO 8601 duration after key creation before automatic rotation occurs."
  default     = "P12M"
}

variable "cmk_key_expire_after" {
  type        = string
  description = "ISO 8601 duration after key creation when each key version expires."
  default     = "P18M"
}

variable "cmk_key_notify_before_expiry" {
  type        = string
  description = "ISO 8601 duration before key expiry to emit Key Vault expiry notifications."
  default     = "P30D"
}

variable "disk_encryption_set_name" {
  type        = string
  description = "Disk Encryption Set name for AVD session host managed disks."
}

variable "disk_encryption_set_identity_name" {
  type        = string
  description = "User-assigned managed identity name used by the Disk Encryption Set to access the CMK."
}

variable "avd_service_principal_object_id" {
  type        = string
  description = "Object ID of the Azure Virtual Desktop service principal that reads session host admin secrets."
}

variable "hub_dns_zone_rg" {
  type        = string
  description = "Hub resource group containing private DNS zones."
}

variable "rg_network" {
  type        = string
  description = "Network resource group name."
}

variable "vnet_name" {
  type        = string
  description = "Spoke virtual network name."
}

variable "pesubnet_keyvault" {
  type        = string
  description = "Key Vault private endpoint subnet name."
}
variable "keyvault_pe_name" {
  type        = string
  description = "Key Vault private endpoint name."
}
variable "keyvault_sc_name" {
  type        = string
  description = "Key Vault service connection name."
}

variable "purge_protection_enabled" {
  type        = bool
  description = "Whether purge protection is enabled for the Key Vault."
  default     = true
}

variable "soft_delete_retention_days" {
  type        = number
  description = "Number of days to retain soft-deleted Key Vault objects."
  default     = 90
}
