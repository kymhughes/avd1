variable "location" {
  type        = string
  description = "Resource group and gallery location."
}

variable "aib_rg" {
  type        = string
  description = "Resource group for the Azure Compute Gallery."
}

variable "rg_network" {
  type        = string
  description = "Network resource group name."
}

variable "vnet_name" {
  type        = string
  description = "Spoke virtual network name."
}

variable "tags" {
  description = "Tags to be used for this resource deployment."
  type        = map(any)
  default     = null
}

variable "publisher" {
  type        = string
  description = "Image definition publisher."
}

variable "offer" {
  type        = string
  description = "Image definition offer."
}

variable "sku" {
  type        = string
  description = "Image definition SKU."
}

variable "compute_gallery_name" {
  type        = string
  description = "Azure Compute Gallery name."
}

variable "gallery_image_definition_name" {
  type        = string
  description = "Azure Compute Gallery image definition name."
}

variable "aib_user_assigned_identity_name" {
  type        = string
  description = "User-assigned managed identity name used by Azure Image Builder."
}

variable "aib_role_definition_name" {
  type        = string
  description = "Custom role definition name assigned to the Azure Image Builder identity."
}
