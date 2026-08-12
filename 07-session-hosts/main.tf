# ── Session Hosts — NICs, Windows VMs, AAD Join, DSC Registration ─────────────
# Depends on: 01 (rg_compute_name), 02 (subnet_id), 04 (vm_password_value), 05 (hostpool_name, registration_token)
# Provides:   vm_ids, vm_names → consumed by 08-rbac
#
# Prerequisites:
#   Register feature: az feature register --name EncryptionAtHost --namespace Microsoft.Compute
#   Wait for: az feature show --name EncryptionAtHost --namespace Microsoft.Compute --query properties.state
#
# NOTE: DSC extension protected_settings is ignored in lifecycle to prevent
#       perpetual destroy/create when DSC state changes after initial registration.

# ── Read hostpool name and registration token directly from module 05 state ──────────
# This eliminates the need to pass registration_token and hostpool_name as -var flags.
# The token is automatically refreshed whenever module 05 state is updated.
data "terraform_remote_state" "avd_hostpool" {
  backend = "local"
  config = {
    path = coalesce(var.hostpool_state_path, "${path.module}/../05-avd-hostpool/terraform.tfstate")
  }
}

locals {
  vm_name_prefix = "${var.prefix}-avd-${var.app_name}-vm"
  # Use variable override if provided, otherwise read from module 05 state
  hostpool_name      = coalesce(var.hostpool_name, data.terraform_remote_state.avd_hostpool.outputs.hostpool_name)
  registration_token = coalesce(var.registration_token, data.terraform_remote_state.avd_hostpool.outputs.registration_token)
  tags = {
    environment     = var.environment
    ServiceWorkload = "Azure Virtual Desktop"
    ManagedBy       = "Terraform"
  }

  # FSLogix profile configuration script.
  # Windows 11 AVD marketplace images (win11-*-avd) include the FSLogix agent pre-installed,
  # so only registry keys are required — no installer download needed.
  # The UNC path uses the storage account FQDN for AADKERB (Entra Kerberos) auth.
  fslogix_script = <<-PSEOF
    $ProfileRegPath = "HKLM:\SOFTWARE\FSLogix\Profiles"
    if (-not (Test-Path $ProfileRegPath)) { New-Item -Path $ProfileRegPath -Force | Out-Null }
    Set-ItemProperty -Path $ProfileRegPath -Name "Enabled"                              -Value 1     -Type DWord
    Set-ItemProperty -Path $ProfileRegPath -Name "VHDLocations"                         -Value "\\${var.fslogix_storage_account_name}.file.core.windows.net\${var.fslogix_share_name}" -Type MultiString
    Set-ItemProperty -Path $ProfileRegPath -Name "DeleteLocalProfileWhenVHDShouldApply" -Value 1     -Type DWord
    Set-ItemProperty -Path $ProfileRegPath -Name "FlipFlopProfileDirectoryName"         -Value 1     -Type DWord
    Set-ItemProperty -Path $ProfileRegPath -Name "PreventLoginWithFailure"              -Value 1     -Type DWord
    Set-ItemProperty -Path $ProfileRegPath -Name "PreventLoginWithTempProfile"          -Value 1     -Type DWord
    Set-ItemProperty -Path $ProfileRegPath -Name "SizeInMBs"                            -Value ${var.fslogix_profile_size_mb} -Type DWord
    Set-ItemProperty -Path $ProfileRegPath -Name "IsDynamic"                            -Value 1     -Type DWord
    Write-Output "FSLogix registry configuration complete."
  PSEOF
}

# Rotating token anchor — refreshed every 2 hours
resource "time_rotating" "avd_token" {
  rotation_minutes = 120
}

# ── Network Interfaces ────────────────────────────────────────────────────────
resource "azurerm_network_interface" "avd_vm_nic" {
  count               = var.rdsh_count
  name                = "${local.vm_name_prefix}-${count.index + 1}-nic"
  resource_group_name = var.rg_compute_name
  location            = var.avdLocation
  tags                = local.tags

  ip_configuration {
    name                          = "nic${count.index + 1}_config"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
  }

  lifecycle {
    # Ignore name changes so renaming the prefix does not destroy/recreate the NIC
    ignore_changes = [name]
  }
}

# ── Windows Virtual Machines ──────────────────────────────────────────────────
resource "azurerm_windows_virtual_machine" "avd_vm" {
  count = var.rdsh_count
  name  = "${local.vm_name_prefix}-${count.index + 1}"
  # computer_name must be ≤15 chars (Windows limit); derived independently of the VM name.
  computer_name              = "${substr(var.prefix, 0, 4)}${substr(var.app_name, 0, 4)}vm${count.index + 1}"
  resource_group_name        = var.rg_compute_name
  location                   = var.avdLocation
  size                       = var.vm_size
  admin_username             = var.local_admin_username
  admin_password             = var.vm_password
  encryption_at_host_enabled = true
  tags                       = local.tags

  network_interface_ids = [
    azurerm_network_interface.avd_vm_nic[count.index].id
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    name                 = "${local.vm_name_prefix}-${count.index + 1}-osdisk"
  }

  source_image_reference {
    publisher = var.publisher
    offer     = var.offer
    sku       = var.sku
    version   = var.image_version
  }

  identity {
    type = "SystemAssigned"
  }
  lifecycle {
    prevent_destroy = true
    # Ignore ForceNew attributes that change when prefix/image is updated in tfvars.
    # To intentionally replace a VM, taint it first: terraform taint <resource>
    ignore_changes = [
      admin_password,
      name,                   # prefix changes would rename the VM (ForceNew)
      computer_name,          # ForceNew — set once at creation
      os_disk,                # disk name contains the VM name (ForceNew)
      source_image_reference, # image changes must not force VM recreation
    ]
  }
}

# ── AAD Join Extension ────────────────────────────────────────────────────────
resource "azurerm_virtual_machine_extension" "aadjoin" {
  count                      = var.rdsh_count
  name                       = "${local.vm_name_prefix}-${count.index + 1}-AADLoginForWindows"
  virtual_machine_id         = azurerm_windows_virtual_machine.avd_vm[count.index].id
  publisher                  = "Microsoft.Azure.ActiveDirectory"
  type                       = "AADLoginForWindows"
  type_handler_version       = "2.0"
  auto_upgrade_minor_version = true
  tags                       = local.tags

  depends_on = [azurerm_windows_virtual_machine.avd_vm]

  lifecycle {
    ignore_changes = [name]
  }
}

# ── DSC AVD Agent Registration Extension ─────────────────────────────────────
resource "azurerm_virtual_machine_extension" "vmext_dsc" {
  count                      = var.rdsh_count
  name                       = "${local.vm_name_prefix}-${count.index + 1}-avd-dsc"
  virtual_machine_id         = azurerm_windows_virtual_machine.avd_vm[count.index].id
  publisher                  = "Microsoft.Powershell"
  type                       = "DSC"
  type_handler_version       = "2.73"
  auto_upgrade_minor_version = true
  tags                       = local.tags

  settings = jsonencode({
    modulesUrl            = "https://wvdportalstorageblob.blob.core.windows.net/galleryartifacts/Configuration_09-08-2022.zip"
    configurationFunction = "Configuration.ps1\\AddSessionHost"
    properties = {
      HostPoolName = local.hostpool_name
      aadJoin      = true
    }
  })

  protected_settings = jsonencode({
    properties = {
      registrationInfoToken = local.registration_token
    }
  })

  lifecycle {
    ignore_changes = [protected_settings, name]
  }

  depends_on = [
    azurerm_virtual_machine_extension.aadjoin,
    time_rotating.avd_token
  ]
}

# ── FSLogix Profile Configuration (Custom Script Extension) ──────────────────
# Writes FSLogix registry keys so session hosts mount Azure Files profiles.
# Runs after DSC (AVD registration) to ensure the VM is fully joined first.
# Script is idempotent — safe to re-run; protected_settings ignored in lifecycle
# to avoid re-running on every plan unless var.fslogix_storage_account_name changes.
resource "azurerm_virtual_machine_extension" "fslogix" {
  count                      = var.rdsh_count
  name                       = "${local.vm_name_prefix}-${count.index + 1}-fslogix"
  virtual_machine_id         = azurerm_windows_virtual_machine.avd_vm[count.index].id
  publisher                  = "Microsoft.Compute"
  type                       = "CustomScriptExtension"
  type_handler_version       = "1.10"
  auto_upgrade_minor_version = true
  tags                       = local.tags

  # script is base64-encoded PowerShell; the CSE executes it directly as a .ps1 file.
  protected_settings = jsonencode({
    script = base64encode(local.fslogix_script)
  })

  lifecycle {
    ignore_changes = [protected_settings]
  }

  depends_on = [
    azurerm_virtual_machine_extension.vmext_dsc
  ]
}
