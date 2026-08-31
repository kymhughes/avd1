output "storage_account_ids" {
  value = { for key, account in module.storage_account : key => account.storage_account_id }
}

output "storage_account_names" {
  value = { for key, account in module.storage_account : key => account.storage_account_name }
}

output "share_ids" {
  value = {
    for share in flatten([
      for storage_key, account in module.storage_account : [
        for share_key, id in account.share_ids : {
          key = "${storage_key}.${share_key}"
          id  = id
        }
      ]
    ]) : share.key => share.id
  }
}

output "share_names" {
  value = {
    for share in flatten([
      for storage_key, account in module.storage_account : [
        for share_key, name in account.share_names : {
          key  = "${storage_key}.${share_key}"
          name = name
        }
      ]
    ]) : share.key => share.name
  }
}

output "share_smb_role_assignment_ids" {
  value = {
    for assignment in flatten([
      for storage_key, account in module.storage_account : [
        for assignment_key, id in account.share_smb_role_assignment_ids : {
          key = "${storage_key}.${assignment_key}"
          id  = id
        }
      ]
    ]) : assignment.key => assignment.id
  }
}

output "share_smb_admin_role_assignment_ids" {
  value = {
    for assignment in flatten([
      for storage_key, account in module.storage_account : [
        for assignment_key, id in account.share_smb_admin_role_assignment_ids : {
          key = "${storage_key}.${assignment_key}"
          id  = id
        }
      ]
    ]) : assignment.key => assignment.id
  }
}
