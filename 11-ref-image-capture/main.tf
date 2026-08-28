resource "azurerm_virtual_machine_extension" "sysprep" {
  name                 = "sysPrep"
  virtual_machine_id   = azurerm_windows_virtual_machine.reference.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"

  settings = jsonencode({
    commandToExecute = "powershell -ExecutionPolicy Bypass -Command \"& $env:SystemRoot\\System32\\Sysprep\\Sysprep.exe /oobe /generalize /shutdown\""
  })
}

