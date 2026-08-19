rg_network = "rg-itm-network-tst"
vnet_name  = "vnet-itm-vnet-tst"

subnets = {
  "snet-itm-001" = {
    name                              = "itm001"
    address_prefixes                  = ["172.17.110.0/28"]
    private_subnet_enabled            = true
    private_endpoint_network_policies = "Disabled"
    nsg = {
      create = true
      security_rules = {
        "Allow-HTTPS-Inbound" = {
          priority                   = 100
          direction                  = "Inbound"
          access                     = "Allow"
          protocol                   = "Tcp"
          source_address_prefix      = "VirtualNetwork"
          destination_address_prefix = "*"
          destination_port_range     = "443"
        }
        "Allow-any-Outbound" = {
          priority                   = 110
          direction                  = "Outbound"
          access                     = "Allow"
          protocol                   = "*"
          source_address_prefix      = "VirtualNetwork"
          destination_address_prefix = "*"
          destination_port_range     = "*"
        }
      }
    }
  }

  "snet-itm-001-pe" = {
    address_prefixes                  = ["172.17.101.0/28"]
    private_subnet_enabled            = true
    private_endpoint_network_policies = "Enabled"
    nsg = {
      create = true
      security_rules = {
        "Allow-HTTPS-Inbound" = {
          priority                   = 100
          direction                  = "Inbound"
          access                     = "Allow"
          protocol                   = "Tcp"
          source_address_prefix      = "VirtualNetwork"
          destination_address_prefix = "*"
          destination_port_range     = "443"
        }
      }
    }
  }

  "snet-itm-002" = {
    name                              = "itm002"
    address_prefixes                  = ["172.17.110.16/28"]
    private_subnet_enabled            = true
    private_endpoint_network_policies = "Disabled"
    nsg                               = { create = true }
  }

  "snet-itm-002-pe" = {
    address_prefixes                  = ["172.17.111.16/28"]
    private_subnet_enabled            = true
    private_endpoint_network_policies = "Enabled"
    nsg                               = { create = true }
  }

  "snet-general-pe" = {
    name                              = "general"
    address_prefixes                  = ["172.17.110.240/28"]
    private_subnet_enabled            = true
    private_endpoint_network_policies = "Enabled"
    nsg = {
      create = true
      security_rules = {
        "Allow-HTTPS-Inbound" = {
          priority                   = 100
          direction                  = "Inbound"
          access                     = "Allow"
          protocol                   = "Tcp"
          source_address_prefix      = "VirtualNetwork"
          destination_address_prefix = "*"
          destination_port_range     = "443"
        }
      }
    }
  }
}
