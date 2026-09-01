rg_network = "rg-itm-network-npd"
vnet_name  = "vnet-itm-vnet-npd"

subnets = {
  "snet-itm-001" = {
    name                              = "itm001"
    address_prefixes                  = ["172.17.100.0/28"]
    private_subnet_enabled            = true
    private_endpoint_network_policies = "Disabled"
    nsg = {
      create = true
      security_rules = {
        "Allow-HTTPS-Inbound" = {
          priority                   = 110
          direction                  = "Inbound"
          access                     = "Allow"
          protocol                   = "Tcp"
          source_address_prefix      = "*"
          destination_address_prefix = "*"
          destination_port_range     = "3389"
        }
        "Allow-any-Outbound" = {
          priority                   = 120
          direction                  = "Outbound"
          access                     = "Allow"
          protocol                   = "*"
          source_address_prefix      = "*"
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
          source_address_prefix      = "*"
          destination_address_prefix = "*"
          destination_port_range     = "443"
        }
      }
    }
  }

  "snet-itm-002" = {
    name                              = "itm002"
    address_prefixes                  = ["172.17.100.16/28"]
    private_subnet_enabled            = true
    private_endpoint_network_policies = "Disabled"
    nsg = {
      create = true
      security_rules = {
        "Allow-HTTPS-Inbound" = {
          priority                   = 110
          direction                  = "Inbound"
          access                     = "Allow"
          protocol                   = "Tcp"
          source_address_prefix      = "*"
          destination_address_prefix = "*"
          destination_port_range     = "3389"
        }
        "Allow-any-Outbound" = {
          priority                   = 120
          direction                  = "Outbound"
          access                     = "Allow"
          protocol                   = "*"
          source_address_prefix      = "*"
          destination_address_prefix = "*"
          destination_port_range     = "*"
        }
      }
    }
  }

  "snet-itm-002-pe" = {
    address_prefixes                  = ["172.17.101.16/28"]
    private_subnet_enabled            = true
    private_endpoint_network_policies = "Enabled"
    nsg                               = { create = true }
  }

  "snet-general-pe" = {
    name                              = "general"
    address_prefixes                  = ["172.17.100.240/28"]
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
          source_address_prefix      = "*"
          destination_address_prefix = "*"
          destination_port_range     = "443"
        }
        "Allow-SMB-Inbound" = {
          priority                   = 200
          direction                  = "Inbound"
          access                     = "Allow"
          protocol                   = "Tcp"
          source_address_prefix      = "*"
          destination_address_prefix = "*"
          destination_port_range     = "445"
        }
      }
    }
  }
  "snet-ib1-vms" = {
    name                              = "ib1-vms"
    address_prefixes                  = ["172.17.100.192/28"]
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
          source_address_prefix      = "*"
          destination_address_prefix = "*"
          destination_port_range     = "443"
        }
      }
    }
  }
  "snet-ib2-tools" = {
    name                              = "ib2-tools"
    address_prefixes                  = ["172.17.100.224/28"]
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
          source_address_prefix      = "*"
          destination_address_prefix = "*"
          destination_port_range     = "443"
        }
      }
    }
} }
