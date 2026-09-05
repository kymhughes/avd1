variable "location" {
  type        = string
  description = "Resource group location. Make sure you are deploying in a location where Azure Image Builder is supported"
}

variable "aib_rg" {
  type        = string
  description = "Resource group for the Azure Image Builder"
}

variable "tags" {
  description = "Tags to be used for this resource deployment."
  type        = map(any)
  default     = null
}

variable "publisher" {
  type        = string
  description = "Image publisher"
}

variable "offer" {
  type        = string
  description = "Image offer"
}

variable "sku" {
  type        = string
  description = "Image SKU"
}

variable "source_image_version" {
  type        = string
  description = "Source platform image version for Azure Image Builder."
  default     = "latest"
}

variable "compute_gallery_name" {
  type        = string
  description = "Azure Compute Gallery name for the image output."
}

variable "gallery_image_definition_name" {
  type        = string
  description = "Azure Compute Gallery image definition name for the image output."
}

variable "image_template_name" {
  type        = string
  description = "Azure Image Builder image template name."
}

variable "run_output_name" {
  type        = string
  description = "Azure Image Builder run output name."
}

variable "image_replication_regions" {
  type        = list(string)
  description = "Image replication regions"
}

variable "aib_region" {
  type        = string
  description = "Image builder region"
}

variable "aib_subnet_id" {
  type        = string
  description = "Existing subnet resource ID for the Azure Image Builder build VM. Leave blank to use the default Image Builder networking."
  default     = ""
}

variable "aib_container_instance_subnet_id" {
  type        = string
  description = "Existing subnet resource ID for Azure Image Builder container/proxy resources. Leave blank to use the Image Builder default."
  default     = ""
}

variable "aib_api_version" {
  type        = string
  description = "Image builder API version"
  default     = "2022-02-14"
}

variable "optimization_script_uri" {
  type        = string
  description = "URI for the PowerShell script used by Azure Image Builder to optimize the image"
}
variable "rg_network" {
  type        = string
  description = "Network resource group name."
}

variable "vnet_name" {
  type        = string
  description = "Spoke virtual network name."
}