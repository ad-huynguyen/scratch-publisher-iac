resource "azurerm_postgresql_flexible_server" "this" {
  name                         = var.postgres_name
  resource_group_name          = var.resource_group_name
  location                     = var.location
  version                      = "16"
  sku_name                     = "GP_Standard_D2s_v3"
  storage_mb                   = 32768
  backup_retention_days        = 7
  geo_redundant_backup_enabled = false
  zone                         = var.zone

  # VNet integration (when delegated_subnet_id is provided)
  delegated_subnet_id = var.delegated_subnet_id
  private_dns_zone_id = var.delegated_subnet_id != null ? var.private_dns_zone_id : null

  # Public endpoint mode (when delegated_subnet_id is null)
  public_network_access_enabled = var.delegated_subnet_id == null ? var.public_network_access : false

  authentication {
    active_directory_auth_enabled = true
    password_auth_enabled         = true # Required for initial setup
    tenant_id                     = var.aad_tenant_id
  }

  administrator_login    = var.administrator_login
  administrator_password = var.administrator_password
}

# Firewall rule for Azure services (only when using public endpoint)
resource "azurerm_postgresql_flexible_server_firewall_rule" "allow_azure" {
  count            = var.delegated_subnet_id == null && var.public_network_access ? 1 : 0
  name             = "AllowAzureServices"
  server_id        = azurerm_postgresql_flexible_server.this.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

resource "azurerm_postgresql_flexible_server_active_directory_administrator" "aad_admin" {
  server_name         = azurerm_postgresql_flexible_server.this.name
  resource_group_name = var.resource_group_name
  tenant_id           = var.aad_tenant_id
  object_id           = var.aad_principal_id
  principal_name      = var.aad_principal_name
  principal_type      = "User"
}

# db-admin AAD group as PostgreSQL administrator (RBAC-7, VD-133)
# This group has DBO permissions on the database
resource "azurerm_postgresql_flexible_server_active_directory_administrator" "db_admin_group" {
  count               = var.enable_db_admin_group ? 1 : 0
  server_name         = azurerm_postgresql_flexible_server.this.name
  resource_group_name = var.resource_group_name
  tenant_id           = var.aad_tenant_id
  object_id           = var.db_admin_group_id
  principal_name      = var.db_admin_group_name
  principal_type      = "Group"
}
