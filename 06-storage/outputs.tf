output "storage_account_ids" {
  value = { for key, account in azapi_resource.storage_account : key => account.id }
}

output "storage_account_names" {
  value = { for key, account in azapi_resource.storage_account : key => account.name }
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
