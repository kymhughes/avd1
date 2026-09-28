output "key_vault_id" {
  description = "Resource ID of the Key Vault."
  value       = module.avm_res_keyvault_vault.resource_id
}

output "cmk_key_id" {
  description = "Versioned Key Vault key URI for the CMK."
  value       = azurerm_key_vault_key.cmk.id
}

output "cmk_key_versionless_id" {
  description = "Versionless Key Vault key URI for rotation-friendly CMK consumers."
  value       = azurerm_key_vault_key.cmk.versionless_id
}

output "disk_encryption_set_id" {
  description = "Resource ID of the AVD Disk Encryption Set."
  value       = azurerm_disk_encryption_set.avd.id
}

output "disk_encryption_set_identity_principal_id" {
  description = "Principal ID of the Disk Encryption Set user-assigned managed identity."
  value       = azurerm_user_assigned_identity.disk_encryption_set.principal_id
}
