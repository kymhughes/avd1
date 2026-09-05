output "resource_group_name" {
  value = data.azurerm_resource_group.aib.name
}

output "location" {
  value = data.azurerm_resource_group.aib.location
}

output "aib_user_assigned_identity_id" {
  value = var.aib_user_assigned_identity_id
}

output "destination_gallery_image_id" {
  value = var.destination_gallery_image_id
}