output "storage_account_id" {
  value = azapi_resource.storage_account.id
}

output "storage_account_name" {
  value = azapi_resource.storage_account.name
}

output "share_ids" {
  value = { for key, share in azapi_resource.shares : key => share.id }
}

output "share_names" {
  value = { for key, share in azapi_resource.shares : key => share.name }
}

output "share_smb_role_assignment_ids" {
  value = { for key, assignment in azurerm_role_assignment.share_smb : key => assignment.id }
}

output "share_smb_admin_role_assignment_ids" {
  value = { for key, assignment in azurerm_role_assignment.share_smb_admin : key => assignment.id }
}
