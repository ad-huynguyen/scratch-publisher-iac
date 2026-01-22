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

module "postgres" {
  source                     = "__MODULE_DIR__"
  resource_group_name        = var.metadata.resourceGroupName
  location                   = var.metadata.location
  postgres_name              = module.naming.postgres_name
  delegated_subnet_id        = "/subscriptions/${var.metadata.subscriptionId}/resourceGroups/${var.metadata.resourceGroupName}/providers/Microsoft.Network/virtualNetworks/${module.naming.vnet_name}/subnets/${module.naming.subnet_postgres_name}"
  private_dns_zone_id        = "/subscriptions/${var.metadata.subscriptionId}/resourceGroups/${var.metadata.resourceGroupName}/providers/Microsoft.Network/privateDnsZones/${module.naming.private_dns_zones["postgres"]}"
  administrator_login        = var.parameters.postgres_admin_login
  administrator_password     = var.parameters.postgres_admin_password
  aad_tenant_id              = var.parameters.tenant_id
  aad_principal_id           = var.parameters.postgres_aad_principal_id
  aad_principal_name         = var.parameters.postgres_aad_principal_name
}
