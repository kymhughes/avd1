# resource "azurerm_resource_group" "this" {
#   count = var.create_resource_group ? 1 : 0

#   name     = var.resource_group_name
#   location = var.location
#   tags     = var.tags
# }

data "azurerm_resource_group" "existing" {
  name = var.rg_network
}

data "azurerm_virtual_network" "existing" {
  name                = var.vnet_name
  resource_group_name = var.rg_network
}


# resource "azurerm_resource_group" "this" {
#   for_each = {
#     for k, v in var.subnets :
#     k => v
#     if try(v.name, null) != null
#   }

#   name     = "rg-${each.value.name}"
#   location = var.avdLocation
# }

resource "azurerm_subnet" "this" {
  for_each = var.subnets

  name                                          = each.key
  resource_group_name                           = var.rg_network
  virtual_network_name                          = var.vnet_name
  address_prefixes                              = each.value.address_prefixes
  service_endpoints                             = each.value.service_endpoints
  default_outbound_access_enabled               = !each.value.private_subnet_enabled
  private_endpoint_network_policies             = each.value.private_endpoint_network_policies
  private_link_service_network_policies_enabled = each.value.private_link_service_network_policies_enabled

  dynamic "delegation" {
    for_each = each.value.delegations

    content {
      name = delegation.key

      service_delegation {
        name    = delegation.value.service_name
        actions = delegation.value.actions
      }
    }
  }
}


resource "azurerm_network_security_group" "subnet" {
  for_each = {
    for subnet_key, subnet in var.subnets : subnet_key => subnet
    if try(subnet.nsg.create, false)
  }

  name                = "nsg-${each.key}"
  location            = var.avdLocation
  resource_group_name = var.rg_network
  tags                = var.tags
}



locals {
  #resource_group_name     = data.azurerm_resource_group.existing[0].name
  #resource_group_location = data.azurerm_resource_group.existing[0].location

  subnet_nsg_associations = {
    for subnet_key, subnet in var.subnets : subnet_key => subnet
    if try(subnet.nsg.create, false) || try(subnet.nsg.existing_network_security_group_id, null) != null
  }

  subnet_nsg_rules = {
    for item in flatten([
      for subnet_key, subnet in var.subnets : [
        for rule_key, rule in try(subnet.nsg.security_rules, {}) : {
          key        = "${subnet_key}.${rule_key}"
          name       = rule_key
          subnet_key = subnet_key
          rule       = rule
        }
      ] if try(subnet.nsg.create, false)
    ]) : item.key => item
  }

  #   reverse_vnet_peerings = {
  #     for peering_key, peering in var.vnet_peerings : peering_key => peering
  #     if peering.create_reverse_peering
  #   }
  # }

  # resource "azurerm_virtual_network" "this" {
  #   name                = var.vnet_name
  #   location            = local.resource_group_location
  #   resource_group_name = local.resource_group_name
  #   address_space       = var.vnet_address_space
  #   dns_servers         = var.dns_servers
  #   tags                = var.tags
}


resource "azurerm_network_security_rule" "subnet" {
  for_each = local.subnet_nsg_rules

  name                        = each.value.name
  priority                    = each.value.rule.priority
  direction                   = each.value.rule.direction
  access                      = each.value.rule.access
  protocol                    = each.value.rule.protocol
  description                 = each.value.rule.description
  resource_group_name         = var.rg_network
  network_security_group_name = azurerm_network_security_group.subnet[each.value.subnet_key].name

  source_port_range = (
    each.value.rule.source_port_range == null && each.value.rule.source_port_ranges == null
    ? "*"
    : each.value.rule.source_port_range
  )
  source_port_ranges = each.value.rule.source_port_ranges

  destination_port_range = (
    each.value.rule.destination_port_range == null && each.value.rule.destination_port_ranges == null
    ? "*"
    : each.value.rule.destination_port_range
  )
  destination_port_ranges = each.value.rule.destination_port_ranges

  source_address_prefix = (
    each.value.rule.source_address_prefix == null && each.value.rule.source_address_prefixes == null
    ? "*"
    : each.value.rule.source_address_prefix
  )
  source_address_prefixes = each.value.rule.source_address_prefixes

  destination_address_prefix = (
    each.value.rule.destination_address_prefix == null && each.value.rule.destination_address_prefixes == null
    ? "*"
    : each.value.rule.destination_address_prefix
  )
  destination_address_prefixes = each.value.rule.destination_address_prefixes
}

resource "azurerm_subnet_network_security_group_association" "this" {
  for_each = local.subnet_nsg_associations

  subnet_id = azurerm_subnet.this[each.key].id
  network_security_group_id = (
    try(each.value.nsg.create, false)
    ? azurerm_network_security_group.subnet[each.key].id
    : each.value.nsg.existing_network_security_group_id
  )
}

# resource "azurerm_virtual_network_peering" "local_to_remote" {
#   for_each = var.vnet_peerings

#   name                      = coalesce(each.value.local_peering_name, "peer-${var.vnet_name}-to-${each.key}")
#   resource_group_name       = local.resource_group_name
#   virtual_network_name      = azurerm_virtual_network.this.name
#   remote_virtual_network_id = each.value.remote_virtual_network_id

#   allow_virtual_network_access = each.value.allow_virtual_network_access
#   allow_forwarded_traffic      = each.value.allow_forwarded_traffic
#   allow_gateway_transit        = each.value.allow_gateway_transit
#   use_remote_gateways          = each.value.use_remote_gateways
# }

# resource "azurerm_virtual_network_peering" "remote_to_local" {
#   provider = azurerm.remote
#   for_each = local.reverse_vnet_peerings

#   name                      = coalesce(each.value.reverse_peering_name, "peer-${each.key}-to-${var.vnet_name}")
#   resource_group_name       = each.value.remote_resource_group_name
#   virtual_network_name      = each.value.remote_virtual_network_name
#   remote_virtual_network_id = azurerm_virtual_network.this.id

#   allow_virtual_network_access = each.value.allow_virtual_network_access
#   allow_forwarded_traffic      = each.value.allow_forwarded_traffic
#   allow_gateway_transit        = each.value.reverse_allow_gateway_transit
#   use_remote_gateways          = each.value.reverse_use_remote_gateways

#   depends_on = [
#     azurerm_virtual_network_peering.local_to_remote
#   ]
# }
