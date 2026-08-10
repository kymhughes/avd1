# ── RBAC — All AVD Role Assignments ──────────────────────────────────────────
# Depends on: 05 (application_group_id), 06 (storage_account_id), 07 (vm resource group id)
# All role assignments use lifecycle ignore_changes to prevent perpetual replace
# caused by AzureRM provider switching between role_definition_id and role_definition_name.

data "azuread_group" "avd_users" {
  display_name     = var.user_group_name
  security_enabled = true
}

# ── Desktop Virtualization User on Application Group ─────────────────────────
# NOTE: This role is already assigned by module 05 via the AVM applicationgroup
# module's role_assignments block. It is NOT managed here to avoid duplicates.
# Managed by: 05-avd-hostpool / module.avm_res_desktopvirtualization_applicationgroup

# ── Virtual Machine User Login on Compute Resource Group ─────────────────────
resource "azurerm_role_assignment" "vm_user_login" {
  scope                = var.rg_compute_id
  role_definition_name = "Virtual Machine User Login"
  principal_id         = data.azuread_group.avd_users.object_id

  lifecycle {
    ignore_changes = [role_definition_id, role_definition_name]
  }
}

# ── Storage File Data SMB Share Contributor on FSLogix Storage ────────────────
# Skipped automatically when storage_account_id is null/empty (module 06 not yet deployed)
resource "azurerm_role_assignment" "fslogix_smb" {
  count                = var.storage_account_id != null && var.storage_account_id != "" ? 1 : 0
  scope                = var.storage_account_id
  role_definition_name = "Storage File Data SMB Share Contributor"
  principal_id         = data.azuread_group.avd_users.object_id

  lifecycle {
    ignore_changes = [role_definition_id, role_definition_name]
  }
}

# ── Desktop Virtualization Power On/Off Contributor (for Scaling Plan) ────────
resource "azurerm_role_assignment" "scaling_power" {
  scope                = var.rg_compute_id
  role_definition_name = "Desktop Virtualization Power On Off Contributor"
  principal_id         = var.scaling_plan_service_principal_id

  lifecycle {
    ignore_changes = [role_definition_id, role_definition_name]
  }
}
