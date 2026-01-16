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

resource "azurerm_postgresql_flexible_server" "this" {
  name                          = var.postgres_name
  resource_group_name           = var.resource_group_name
  location                      = var.location
  version                       = "16"
  sku_name                      = "GP_Standard_D2s_v3"
  storage_mb                    = 32768
  backup_retention_days         = 7
  geo_redundant_backup_enabled  = false
  delegated_subnet_id           = var.delegated_subnet_id
  private_dns_zone_id           = var.private_dns_zone_id
  public_network_access_enabled = false
  administrator_login           = var.administrator_login
  administrator_password        = var.administrator_password

  authentication {
    active_directory_auth_enabled = true
    password_auth_enabled         = false
  }
}

resource "azurerm_postgresql_flexible_server_active_directory_administrator" "aad_admin" {
  server_name         = azurerm_postgresql_flexible_server.this.name
  resource_group_name = var.resource_group_name
  tenant_id           = var.aad_tenant_id
  object_id           = var.aad_principal_id
  principal_name      = var.aad_principal_name
  principal_type      = "Group"
}
