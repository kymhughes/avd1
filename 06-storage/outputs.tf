output "storage_account_id" { value = azurerm_storage_account.fslogix.id }
output "storage_account_name" { value = azurerm_storage_account.fslogix.name }
output "fslogix_share_name" { value = azurerm_storage_share.fslogix.name }
output "managed_identity_id" { value = azurerm_user_assigned_identity.storage_mi.id }
output "managed_identity_client_id" { value = azurerm_user_assigned_identity.storage_mi.client_id }
output "private_endpoint_id" { value = azurerm_private_endpoint.file_pe.id }
