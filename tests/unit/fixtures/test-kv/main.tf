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

module "kv" {
  source                     = "__MODULE_DIR__"
  resource_group_name        = var.metadata.resourceGroupName
  location                   = var.metadata.location
  key_vault_name             = module.naming.key_vault_name
  tenant_id                  = var.parameters.tenant_id
  private_endpoint_subnet_id = "/subscriptions/${var.metadata.subscriptionId}/resourceGroups/${var.metadata.resourceGroupName}/providers/Microsoft.Network/virtualNetworks/${module.naming.vnet_name}/subnets/${module.naming.subnet_private_endpoints_name}"
  private_dns_zone_id        = "/subscriptions/${var.metadata.subscriptionId}/resourceGroups/${var.metadata.resourceGroupName}/providers/Microsoft.Network/privateDnsZones/${module.naming.private_dns_zones["key_vault"]}"
}
