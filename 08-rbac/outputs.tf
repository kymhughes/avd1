output "vm_user_login_ra_id"    { value = azurerm_role_assignment.vm_user_login.id }
output "fslogix_smb_ra_id"      { value = length(azurerm_role_assignment.fslogix_smb) > 0 ? azurerm_role_assignment.fslogix_smb[0].id : null }
output "scaling_power_ra_id"    { value = azurerm_role_assignment.scaling_power.id }
