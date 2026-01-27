# Provider inherited from root module to ensure storage_use_azuread is set

# Get current principal for RBAC (required when shared_access_key_enabled = false)
data "azurerm_client_config" "current" {}

resource "azurerm_storage_account" "this" {
  name                     = var.storage_account_name
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"
  min_tls_version          = "TLS1_2"
  # Note: shared_access_key required for azurerm provider table ACL operations
  # TODO: Disable once azurerm provider supports AAD-only for all table operations
  shared_access_key_enabled = true
  # Public access enabled for AAD-authenticated provisioning (queue/table creation)
  # Private endpoints still enforce network isolation for data plane access from VNet
  # Note: Tighten network_rules after initial deployment if needed
  public_network_access_enabled = true

  network_rules {
    default_action             = "Allow" # Required for Terraform provisioning with AAD auth
    bypass                     = ["AzureServices"]
    ip_rules                   = []
    virtual_network_subnet_ids = []
  }

  # Known azurerm provider issue: network_rules shows drift when default_action=Allow
  # https://github.com/hashicorp/terraform-provider-azurerm/issues/25583
  lifecycle {
    ignore_changes = [network_rules]
  }
}

# RBAC assignments for deploying principal (required when shared_access_key_enabled = false)
resource "azurerm_role_assignment" "storage_queue_contributor" {
  scope                = azurerm_storage_account.this.id
  role_definition_name = "Storage Queue Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_role_assignment" "storage_table_contributor" {
  scope                = azurerm_storage_account.this.id
  role_definition_name = "Storage Table Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_storage_queue" "queue" {
  name                 = var.queue_name
  storage_account_name = azurerm_storage_account.this.name

  depends_on = [azurerm_role_assignment.storage_queue_contributor]
}

resource "azurerm_storage_table" "table" {
  name                 = var.table_name
  storage_account_name = azurerm_storage_account.this.name

  depends_on = [azurerm_role_assignment.storage_table_contributor]
}

resource "azurerm_private_endpoint" "blob" {
  name                = "${var.storage_account_name}-pe-blob"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id

  private_service_connection {
    name                           = "${var.storage_account_name}-blob-psc"
    private_connection_resource_id = azurerm_storage_account.this.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "blob-dns"
    private_dns_zone_ids = [var.private_dns_zone_ids["blob"]]
  }
}

resource "azurerm_private_endpoint" "queue" {
  name                = "${var.storage_account_name}-pe-queue"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id

  private_service_connection {
    name                           = "${var.storage_account_name}-queue-psc"
    private_connection_resource_id = azurerm_storage_account.this.id
    subresource_names              = ["queue"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "queue-dns"
    private_dns_zone_ids = [var.private_dns_zone_ids["queue"]]
  }
}

resource "azurerm_private_endpoint" "table" {
  name                = "${var.storage_account_name}-pe-table"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id

  private_service_connection {
    name                           = "${var.storage_account_name}-table-psc"
    private_connection_resource_id = azurerm_storage_account.this.id
    subresource_names              = ["table"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "table-dns"
    private_dns_zone_ids = [var.private_dns_zone_ids["table"]]
  }
}
