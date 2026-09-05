output "resource_group_name" {
  value = azurerm_resource_group.image_gallery.name
}

output "compute_gallery_id" {
  value = azurerm_shared_image_gallery.this.id
}

output "compute_gallery_name" {
  value = azurerm_shared_image_gallery.this.name
}

output "gallery_image_definition_id" {
  value = azurerm_shared_image.this.id
}

output "gallery_image_definition_name" {
  value = azurerm_shared_image.this.name
}

output "aib_user_assigned_identity_id" {
  value = azurerm_user_assigned_identity.aib.id
}

output "aib_user_assigned_identity_name" {
  value = azurerm_user_assigned_identity.aib.name
}

output "aib_user_assigned_identity_principal_id" {
  value = azurerm_user_assigned_identity.aib.principal_id
}
