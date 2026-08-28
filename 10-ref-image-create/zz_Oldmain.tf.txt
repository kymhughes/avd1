resource "azurerm_windows_virtual_machine" "reference" {
  name                = "avd-ref-01"
  location            = var.location
  resource_group_name = var.rg_name
  size                = "Standard_D4s_v5"

  admin_username = var.admin_username
  admin_password = var.admin_password

  network_interface_ids = [
    azurerm_network_interface.reference.id
  ]

  source_image_id = var.hardened_image_id

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  identity {
    type = "SystemAssigned"
  }
}


resource "azurerm_virtual_machine_extension" "avd_bootloader" {
  name                 = "avdBootLoader"
  virtual_machine_id   = azurerm_windows_virtual_machine.reference.id
  publisher            = "Microsoft.Powershell"
  type                 = "DSC"
  type_handler_version = "2.73"

  settings = <<SETTINGS
{
  "modulesUrl": "${var.avd_dsc_zip_url}",
  "configurationFunction": "Configuration.ps1\\AddSessionHost",
  "properties": {
      "hostPoolName": "${var.hostpool_name}"
  }
}
SETTINGS
}