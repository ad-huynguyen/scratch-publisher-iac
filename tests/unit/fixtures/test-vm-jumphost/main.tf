terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.90.0"
    }
  }
}

variable "metadata" {
  type = object({
    subscriptionId    = string
    resourceGroupName = string
    location          = string
  })
}

variable "parameters" {
  type = any
}

module "naming" {
  source      = "__NAMING_MODULE__"
  prefix      = var.parameters.system_name
  environment = "dev"
  purpose     = "publisher"
}

provider "azurerm" {
  features {}
  subscription_id            = var.metadata.subscriptionId
  tenant_id                  = var.parameters.tenant_id
  skip_provider_registration = true
}

module "vm_jumphost" {
  source              = "__MODULE_DIR__"
  resource_group_name = var.metadata.resourceGroupName
  location            = var.metadata.location
  nic_name            = module.naming.jumphost_nic_name
  vm_name             = module.naming.jumphost_vm_name
  subnet_id           = "/subscriptions/${var.metadata.subscriptionId}/resourceGroups/${var.metadata.resourceGroupName}/providers/Microsoft.Network/virtualNetworks/${module.naming.vnet_name}/subnets/${module.naming.subnet_jumphost_name}"
  vm_size             = "Standard_B2s"
  admin_username      = var.parameters.jumphost_admin_username
  ssh_public_key      = var.parameters.jumphost_ssh_public_key
}
