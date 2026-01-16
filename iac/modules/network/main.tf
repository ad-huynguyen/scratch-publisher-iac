terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.90.0"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_virtual_network" "this" {
  name                = var.vnet_name
  address_space       = var.address_space
  location            = var.location
  resource_group_name = var.resource_group_name
}

resource "azurerm_subnet" "bastion" {
  name                 = var.subnet_bastion_name
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [var.subnet_bastion_prefix]
}

resource "azurerm_subnet" "jumphost" {
  name                 = var.subnet_jumphost_name
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [var.subnet_jumphost_prefix]
}

resource "azurerm_subnet" "private_endpoints" {
  name                                      = var.subnet_private_endpoints_name
  resource_group_name                       = var.resource_group_name
  virtual_network_name                      = azurerm_virtual_network.this.name
  address_prefixes                          = [var.subnet_private_endpoints_prefix]
  private_endpoint_network_policies         = "Disabled"
}

resource "azurerm_subnet" "postgres" {
  name                 = var.subnet_postgres_name
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [var.subnet_postgres_prefix]

  delegation {
    name = "fs"

    service_delegation {
      name = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
      ]
    }
  }
}
