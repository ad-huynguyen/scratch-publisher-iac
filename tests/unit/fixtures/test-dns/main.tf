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

module "dns" {
  source              = "__MODULE_DIR__"
  resource_group_name = var.metadata.resourceGroupName
  zone_names          = module.naming.private_dns_zones
  vnet_id             = "/subscriptions/${var.metadata.subscriptionId}/resourceGroups/${var.metadata.resourceGroupName}/providers/Microsoft.Network/virtualNetworks/${module.naming.vnet_name}"
}
