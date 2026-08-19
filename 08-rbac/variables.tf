variable "tenant_id" {
  type        = string
  description = "Azure AD tenant ID"
}

variable "spoke_subscription_id" {
  type        = string
  description = "Spoke subscription ID"
}

variable "user_group_name" {
  type        = string
  description = "Azure AD security group for AVD users"
}

variable "rg_compute_id" {
  type        = string
  description = "Compute resource group ID (from module 01: rg_compute_id)"
}

variable "storage_account_id" {
  type        = string
  default     = null
  nullable    = true
  description = "FSLogix storage account ID (from module 06: storage_account_id). Leave null to skip the SMB role assignment."
}
variable "scaling_plan_service_principal_id" {
  type        = string
  description = "Object ID of the AVD/Windows Virtual Desktop service principal for scaling plan power operations"
}
