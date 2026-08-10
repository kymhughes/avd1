output "vm_ids" {
  value = [for vm in azurerm_windows_virtual_machine.avd_vm : vm.id]
}

output "vm_names" {
  value = [for vm in azurerm_windows_virtual_machine.avd_vm : vm.name]
}

output "vm_principal_ids" {
  value = [for vm in azurerm_windows_virtual_machine.avd_vm : vm.identity[0].principal_id]
}

output "nic_ids" {
  value = [for nic in azurerm_network_interface.avd_vm_nic : nic.id]
}
