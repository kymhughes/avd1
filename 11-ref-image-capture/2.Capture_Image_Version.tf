resource "azurerm_shared_image_version" "capture" {
  name                = var.version
  gallery_name        = var.gallery_name
  image_name          = var.image_name
  resource_group_name = var.gallery_rg
  location            = var.location

  managed_image_id = azurerm_image.capture.id

  target_region {
    name                   = "australiaeast"
    regional_replica_count = 2
  }
}
