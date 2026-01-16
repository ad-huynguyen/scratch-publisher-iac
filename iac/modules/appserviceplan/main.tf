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

resource "azurerm_service_plan" "this" {
  name                   = var.plan_name
  resource_group_name    = var.resource_group_name
  location               = var.location
  os_type                = "Linux"
  sku_name               = var.sku
  worker_count           = 1
  zone_balancing_enabled = false
}
