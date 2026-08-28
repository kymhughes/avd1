output "resource_group_name" {
  description = "Resource group containing the session host VM."
  value       = azurerm_resource_group.this.name
}

output "vm_id" {
  description = "Session host VM resource ID."
  value       = azurerm_windows_virtual_machine.this.id
}

output "vm_name" {
  description = "Session host VM name."
  value       = azurerm_windows_virtual_machine.this.name
}

output "private_ip_address" {
  description = "Private IP address assigned to the session host VM."
  value       = azurerm_network_interface.this.private_ip_address
}
