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

resource "azurerm_storage_account" "this" {
  name                          = var.storage_account_name
  resource_group_name           = var.resource_group_name
  location                      = var.location
  account_tier                  = "Standard"
  account_replication_type      = "LRS"
  account_kind                  = "StorageV2"
  enable_https_traffic_only     = true
  min_tls_version               = "TLS1_2"
  allow_blob_public_access      = false
  shared_access_key_enabled     = false
  public_network_access_enabled = false
}

resource "azurerm_storage_queue" "queue" {
  name                 = var.queue_name
  storage_account_name = azurerm_storage_account.this.name
}

resource "azurerm_storage_table" "table" {
  name                 = var.table_name
  storage_account_name = azurerm_storage_account.this.name
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
