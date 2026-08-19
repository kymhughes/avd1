

# Network resource group (created here — not in module 01)
resource "azurerm_resource_group" "net" {
  location = var.avdLocation
  name     = var.rg_network
  tags     = var.tags
  lifecycle { prevent_destroy = false }
}

# ── Virtual Network ──────────────────────────────────────────────────────────
resource "azurerm_virtual_network" "vnet" {
  provider            = azurerm.spoke
  name                = var.vnet_name
  address_space       = var.vnet_range
  location            = azurerm_resource_group.net.location
  resource_group_name = azurerm_resource_group.net.name
  dns_servers         = var.dns_servers
  tags                = var.tags
  depends_on          = [azurerm_resource_group.net]
  lifecycle { prevent_destroy = false }
}

# ── VNet Peering: Spoke → Hub ─────────────────────────────────────────────────
data "azurerm_virtual_network" "hub" {
  provider            = azurerm.hub
  name                = var.hub_vnet
  resource_group_name = var.hub_connectivity_rg
}


resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  provider                     = azurerm.spoke
  name                         = data.azurerm_virtual_network.hub.name
  resource_group_name          = azurerm_resource_group.net.name
  virtual_network_name         = azurerm_virtual_network.vnet.name
  remote_virtual_network_id    = data.azurerm_virtual_network.hub.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  depends_on                   = [azurerm_virtual_network.vnet, azurerm_resource_group.net]
}

resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  provider                     = azurerm.hub
  name                         = azurerm_virtual_network.vnet.name
  resource_group_name          = var.hub_connectivity_rg
  virtual_network_name         = var.hub_vnet
  remote_virtual_network_id    = azurerm_virtual_network.vnet.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = true
  depends_on                   = [azurerm_virtual_network.vnet]
}

resource "azurerm_route_table" "this" {
  name                = "rt-${var.vnet_name}"
  location            = var.avdLocation
  resource_group_name = azurerm_resource_group.net.name
}

resource "azurerm_route" "default_to_firewall" {
  name                   = "default-to-firewall"
  resource_group_name    = azurerm_resource_group.net.name
  route_table_name       = azurerm_route_table.this.name
  address_prefix         = "0.0.0.0/0"
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = "172.17.0.36"
}
