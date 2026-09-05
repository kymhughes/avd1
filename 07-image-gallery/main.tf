provider "azurerm" {
  features {}
}

data "azurerm_virtual_network" "existing" {
  name                = var.vnet_name
  resource_group_name = var.rg_network
}

resource "azurerm_resource_group" "image_gallery" {
  name     = var.aib_rg
  location = var.location
  tags     = var.tags
}

resource "azurerm_shared_image_gallery" "this" {
  name                = var.compute_gallery_name
  resource_group_name = azurerm_resource_group.image_gallery.name
  location            = azurerm_resource_group.image_gallery.location
  tags                = var.tags
}

resource "azurerm_shared_image" "this" {
  name                = var.gallery_image_definition_name
  gallery_name        = azurerm_shared_image_gallery.this.name
  resource_group_name = azurerm_resource_group.image_gallery.name
  location            = azurerm_resource_group.image_gallery.location
  os_type             = "Windows"
  hyper_v_generation  = "V2"

  identifier {
    publisher = var.publisher
    offer     = var.offer
    sku       = var.sku
  }
}

resource "azurerm_user_assigned_identity" "aib" {
  name                = var.aib_user_assigned_identity_name
  resource_group_name = azurerm_resource_group.image_gallery.name
  location            = azurerm_resource_group.image_gallery.location
  tags                = var.tags
}

resource "azurerm_role_assignment" "aib_network_contributor" {
  scope                = data.azurerm_virtual_network.existing.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.aib.principal_id
}

resource "azurerm_role_definition" "aib" {
  name        = var.aib_role_definition_name
  scope       = azurerm_resource_group.image_gallery.id
  description = "Azure Image Builder AVD"

  permissions {
    actions = [
      "Microsoft.Authorization/*/read",
      "Microsoft.Compute/images/write",
      "Microsoft.Compute/images/read",
      "Microsoft.Compute/images/delete",
      "Microsoft.Compute/galleries/read",
      "Microsoft.Compute/galleries/images/read",
      "Microsoft.Compute/galleries/images/versions/read",
      "Microsoft.Compute/galleries/images/versions/write",
      "Microsoft.Storage/storageAccounts/blobServices/containers/read",
      "Microsoft.Storage/storageAccounts/blobServices/containers/write",
      "Microsoft.Storage/storageAccounts/blobServices/read",
      "Microsoft.ContainerInstance/containerGroups/read",
      "Microsoft.ContainerInstance/containerGroups/write",
      "Microsoft.ContainerInstance/containerGroups/start/action",
      "Microsoft.ManagedIdentity/userAssignedIdentities/*/read",
      "Microsoft.ManagedIdentity/userAssignedIdentities/*/assign/action",
      "Microsoft.Resources/deployments/*",
      "Microsoft.Resources/deploymentScripts/read",
      "Microsoft.Resources/deploymentScripts/write",
      "Microsoft.Resources/subscriptions/resourceGroups/read",
      "Microsoft.VirtualMachineImages/imageTemplates/run/action",
      "Microsoft.VirtualMachineImages/imageTemplates/read",
      "Microsoft.Network/virtualNetworks/read",
      "Microsoft.Network/virtualNetworks/subnets/join/action"
    ]
    not_actions = []
  }

  assignable_scopes = [
    azurerm_resource_group.image_gallery.id
  ]
}

resource "azurerm_role_assignment" "aib" {
  scope              = azurerm_resource_group.image_gallery.id
  role_definition_id = azurerm_role_definition.aib.role_definition_resource_id
  principal_id       = azurerm_user_assigned_identity.aib.principal_id
}
