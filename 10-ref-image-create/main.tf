locals {
  bootstrap_script = <<-POWERSHELL
    $ErrorActionPreference = 'Stop'
    $ProgressPreference = 'SilentlyContinue'
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    $WorkDir = 'C:\AVDPrep'
    New-Item -Path $WorkDir -ItemType Directory -Force | Out-Null
    Start-Transcript -Path (Join-Path $WorkDir 'bootstrap.log') -Append

    $AvdRegistrationToken = ${jsonencode(var.avd_registration_token)}
    $InstallFslogix = [System.Convert]::ToBoolean('${var.install_fslogix}')
    $FslogixProfileContainerPath = ${jsonencode(var.fslogix_profile_container_unc_path)}
    $CustomAppBlobUrl = ${jsonencode(var.custom_app_blob_url)}
    $CustomAppFileName = ${jsonencode(var.custom_app_file_name)}
    $CustomAppInstallCommand = ${jsonencode(var.custom_app_install_command)}
    $CustomAppExpectedSha256 = ${jsonencode(var.custom_app_expected_sha256)}
    $RebootAfterBootstrap = [System.Convert]::ToBoolean('${var.reboot_after_bootstrap}')

    function Invoke-Download {
      param(
        [Parameter(Mandatory = $true)][string]$Uri,
        [Parameter(Mandatory = $true)][string]$OutFile
      )

      Invoke-WebRequest -Uri $Uri -OutFile $OutFile -UseBasicParsing
      if (-not (Test-Path $OutFile)) {
        throw "Download failed: $Uri"
      }
    }

    function Install-Fslogix {
      $zipPath = Join-Path $WorkDir 'FSLogix.zip'
      $extractPath = Join-Path $WorkDir 'FSLogix'

      Invoke-Download -Uri 'https://aka.ms/fslogix_download' -OutFile $zipPath
      if (Test-Path $extractPath) {
        Remove-Item -Path $extractPath -Recurse -Force
      }
      Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force

      $setup = Get-ChildItem -Path $extractPath -Recurse -Filter 'FSLogixAppsSetup.exe' |
        Where-Object { $_.FullName -match '\\x64\\' } |
        Select-Object -First 1

      if (-not $setup) {
        throw 'FSLogixAppsSetup.exe was not found in the downloaded package.'
      }

      $process = Start-Process -FilePath $setup.FullName -ArgumentList '/install /quiet /norestart' -Wait -PassThru
      if ($process.ExitCode -ne 0 -and $process.ExitCode -ne 3010) {
        throw "FSLogix installer failed with exit code $($process.ExitCode)."
      }

      New-Item -Path 'HKLM:\SOFTWARE\FSLogix\Profiles' -Force | Out-Null
      New-ItemProperty -Path 'HKLM:\SOFTWARE\FSLogix\Profiles' -Name Enabled -PropertyType DWord -Value 1 -Force | Out-Null
      New-ItemProperty -Path 'HKLM:\SOFTWARE\FSLogix\Profiles' -Name DeleteLocalProfileWhenVHDShouldApply -PropertyType DWord -Value 1 -Force | Out-Null
      New-ItemProperty -Path 'HKLM:\SOFTWARE\FSLogix\Profiles' -Name FlipFlopProfileDirectoryName -PropertyType DWord -Value 1 -Force | Out-Null
      New-ItemProperty -Path 'HKLM:\SOFTWARE\FSLogix\Profiles' -Name IsDynamic -PropertyType DWord -Value 1 -Force | Out-Null
      New-ItemProperty -Path 'HKLM:\SOFTWARE\FSLogix\Profiles' -Name VolumeType -PropertyType String -Value 'VHDX' -Force | Out-Null

      if (-not [string]::IsNullOrWhiteSpace($FslogixProfileContainerPath)) {
        New-ItemProperty -Path 'HKLM:\SOFTWARE\FSLogix\Profiles' -Name VHDLocations -PropertyType MultiString -Value $FslogixProfileContainerPath -Force | Out-Null
      }
    }

    function Install-AvdAgent {
      if ([string]::IsNullOrWhiteSpace($AvdRegistrationToken)) {
        Write-Host 'No AVD registration token provided; skipping AVD agent registration.'
        return
      }

      $agentMsi = Join-Path $WorkDir 'Microsoft.RDInfra.RDAgent.Installer-x64.msi'
      $bootLoaderMsi = Join-Path $WorkDir 'Microsoft.RDInfra.RDAgentBootLoader.Installer-x64.msi'

      Invoke-Download -Uri 'https://query.prod.cms.rt.microsoft.com/cms/api/am/binary/RWrmXv' -OutFile $agentMsi
      Invoke-Download -Uri 'https://query.prod.cms.rt.microsoft.com/cms/api/am/binary/RWrxrH' -OutFile $bootLoaderMsi

      $agentArgs = "/i `"$agentMsi`" /quiet /qn /norestart REGISTRATIONTOKEN=`"$AvdRegistrationToken`""
      $agent = Start-Process -FilePath 'msiexec.exe' -ArgumentList $agentArgs -Wait -PassThru
      if ($agent.ExitCode -ne 0 -and $agent.ExitCode -ne 3010) {
        throw "AVD agent install failed with exit code $($agent.ExitCode)."
      }

      $bootLoaderArgs = "/i `"$bootLoaderMsi`" /quiet /qn /norestart"
      $bootLoader = Start-Process -FilePath 'msiexec.exe' -ArgumentList $bootLoaderArgs -Wait -PassThru
      if ($bootLoader.ExitCode -ne 0 -and $bootLoader.ExitCode -ne 3010) {
        throw "AVD bootloader install failed with exit code $($bootLoader.ExitCode)."
      }
    }

    function Install-CustomApp {
      if ([string]::IsNullOrWhiteSpace($CustomAppBlobUrl)) {
        Write-Host 'No custom app blob URL provided; skipping custom app installation.'
        return
      }
      if ([string]::IsNullOrWhiteSpace($CustomAppInstallCommand)) {
        throw 'custom_app_blob_url was provided but custom_app_install_command is empty.'
      }

      $appPath = Join-Path $WorkDir $CustomAppFileName
      Invoke-Download -Uri $CustomAppBlobUrl -OutFile $appPath

      if (-not [string]::IsNullOrWhiteSpace($CustomAppExpectedSha256)) {
        $actualHash = (Get-FileHash -Path $appPath -Algorithm SHA256).Hash
        if ($actualHash -ne $CustomAppExpectedSha256) {
          throw "Custom app hash mismatch. Expected $CustomAppExpectedSha256, got $actualHash."
        }
      }

      $command = $CustomAppInstallCommand.Replace('{file}', ('"{0}"' -f $appPath))
      $install = Start-Process -FilePath 'cmd.exe' -ArgumentList "/c $command" -Wait -PassThru
      if ($install.ExitCode -ne 0 -and $install.ExitCode -ne 3010) {
        throw "Custom app install failed with exit code $($install.ExitCode)."
      }
    }

    function Invoke-InitialWindowsUpdate {
      $session = New-Object -ComObject Microsoft.Update.Session
      $searcher = $session.CreateUpdateSearcher()
      $result = $searcher.Search("IsInstalled=0 and Type='Software'")

      if ($result.Updates.Count -eq 0) {
        Write-Host 'No applicable Windows updates found.'
        return $false
      }

      $updates = New-Object -ComObject Microsoft.Update.UpdateColl
      foreach ($update in $result.Updates) {
        if (-not $update.EulaAccepted) {
          $update.AcceptEula()
        }
        [void]$updates.Add($update)
      }

      $downloader = $session.CreateUpdateDownloader()
      $downloader.Updates = $updates
      [void]$downloader.Download()

      $installer = $session.CreateUpdateInstaller()
      $installer.Updates = $updates
      $installResult = $installer.Install()

      if ($installResult.ResultCode -gt 3) {
        throw "Windows Update failed with result code $($installResult.ResultCode)."
      }

      return [bool]$installResult.RebootRequired
    }

    if ($InstallFslogix) {
      Install-Fslogix
    }

    Install-AvdAgent
    Install-CustomApp
    $UpdateRequiresReboot = Invoke-InitialWindowsUpdate

    Stop-Transcript

    if ($RebootAfterBootstrap -or $UpdateRequiresReboot) {
      Restart-Computer -Force
    }
  POWERSHELL
}

resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

data "azurerm_subnet" "session_hosts" {
  name                 = var.existing_subnet_name
  virtual_network_name = var.existing_vnet_name
  resource_group_name  = var.existing_vnet_resource_group_name
}

resource "azurerm_network_interface" "this" {
  name                = "${var.vm_name}-nic"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = var.tags

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = data.azurerm_subnet.session_hosts.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_windows_virtual_machine" "this" {
  name                = var.vm_name
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  size                = var.vm_size
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  network_interface_ids = [
    azurerm_network_interface.this.id
  ]

  provision_vm_agent       = true
  enable_automatic_updates = true
  patch_mode               = "AutomaticByPlatform"
  patch_assessment_mode    = "AutomaticByPlatform"
  timezone                 = "AUS Eastern Standard Time"

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = var.os_disk_type
  }

  source_image_reference {
    publisher = var.source_image_reference.publisher
    offer     = var.source_image_reference.offer
    sku       = var.source_image_reference.sku
    version   = var.source_image_reference.version
  }

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

resource "azurerm_virtual_machine_extension" "avd_bootstrap" {
  name                       = "avd-bootstrap"
  virtual_machine_id         = azurerm_windows_virtual_machine.this.id
  publisher                  = "Microsoft.Compute"
  type                       = "CustomScriptExtension"
  type_handler_version       = "1.10"
  auto_upgrade_minor_version = true

  protected_settings = jsonencode({
    script = base64encode(local.bootstrap_script)
  })

  tags = var.tags
}
