terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.90.0"
    }
  }
}

provider "azurerm" {
  features {}
  skip_provider_registration = true
}

variable "metadata" {
  type = object({
    subscriptionId    = string
    resourceGroupName = string
    location          = string
  })
}

variable "parameters" {
  type = map(any)
}

module "naming" {
  source      = "__NAMING_MODULE__"
  prefix      = var.parameters.system_name
  environment = "dev"
  purpose     = "publisher"
}

module "network" {
  source                          = "__MODULE_DIR__"
  resource_group_name             = var.metadata.resourceGroupName
  location                        = var.metadata.location
  vnet_name                       = module.naming.vnet_name
  address_space                   = [var.parameters.vnet_cidr]
  subnet_bastion_name             = module.naming.subnet_bastion_name
  subnet_bastion_prefix           = var.parameters.subnet_bastion_cidr
  subnet_jumphost_name            = module.naming.subnet_jumphost_name
  subnet_jumphost_prefix          = var.parameters.subnet_jumphost_cidr
  subnet_private_endpoints_name   = module.naming.subnet_private_endpoints_name
  subnet_private_endpoints_prefix = var.parameters.subnet_private_endpoints_cidr
  subnet_postgres_name            = module.naming.subnet_postgres_name
  subnet_postgres_prefix          = var.parameters.subnet_postgres_cidr
}
