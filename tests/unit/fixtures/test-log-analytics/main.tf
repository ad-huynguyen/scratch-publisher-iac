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

module "log_analytics" {
  source              = "__MODULE_DIR__"
  resource_group_name = var.metadata.resourceGroupName
  location            = var.metadata.location
  workspace_name      = module.naming.log_analytics_workspace_name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}
