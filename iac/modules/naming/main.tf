terraform {
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = ">= 3.6.2"
    }
  }
}

locals {
  resource_group_prefix = "${var.prefix}-rg-${var.purpose}"
  resource_prefix       = "${var.prefix}-${var.purpose}"
}

# Deterministic per-resource nanoids (keepers lock to env + purpose).
resource "random_id" "rg" {
  byte_length = 4 # 8 hex chars
  keepers = {
    environment = var.environment
    purpose     = var.purpose
    scope       = "rg"
  }
}

resource "random_id" "kv" {
  byte_length = 8
  keepers = {
    environment = var.environment
    purpose     = var.purpose
    scope       = "kv"
  }
}

resource "random_id" "acr" {
  byte_length = 8
  keepers = {
    environment = var.environment
    purpose     = var.purpose
    scope       = "acr"
  }
}

resource "random_id" "storage" {
  byte_length = 4
  keepers = {
    environment = var.environment
    purpose     = var.purpose
    scope       = "storage"
  }
}

resource "random_id" "postgres" {
  byte_length = 8
  keepers = {
    environment = var.environment
    purpose     = var.purpose
    scope       = "postgres"
  }
}

resource "random_id" "asp" {
  byte_length = 6
  keepers = {
    environment = var.environment
    purpose     = var.purpose
    scope       = "asp"
  }
}

resource "random_id" "network" {
  byte_length = 6
  keepers = {
    environment = var.environment
    purpose     = var.purpose
    scope       = "vnet"
  }
}

resource "random_id" "bastion" {
  byte_length = 4
  keepers = {
    environment = var.environment
    purpose     = var.purpose
    scope       = "bastion"
  }
}

resource "random_id" "jumphost" {
  byte_length = 4
  keepers = {
    environment = var.environment
    purpose     = var.purpose
    scope       = "jumphost"
  }
}

resource "random_id" "law" {
  byte_length = 4
  keepers = {
    environment = var.environment
    purpose     = var.purpose
    scope       = "law"
  }
}

output "resource_group_name" {
  value = "${local.resource_group_prefix}-${random_id.rg.hex}"
}

output "vnet_name" {
  value = "${var.prefix}-vnet-${var.purpose}-${random_id.network.hex}"
}

output "subnet_bastion_name" {
  value = "AzureBastionSubnet"
}

output "subnet_jumphost_name" {
  value = "snet-jumphost"
}

output "subnet_private_endpoints_name" {
  value = "snet-private-endpoints"
}

output "subnet_postgres_name" {
  value = "snet-postgres"
}

output "storage_account_name" {
  # Storage account names must be 3-24 lower alphanumerics.
  value = lower(replace("${var.prefix}${var.purpose}${random_id.storage.hex}", "/[^a-z0-9]/", ""))
}

output "storage_queue_name" {
  value = "publisher-queue"
}

output "storage_table_name" {
  value = "publishertable"
}

output "key_vault_name" {
  value = "${var.prefix}-kv-${var.purpose}-${random_id.kv.hex}"
}

output "acr_name" {
  value = "${var.prefix}acr${var.purpose}${random_id.acr.hex}"
}

output "postgres_name" {
  value = "${var.prefix}-psql-${var.purpose}-${random_id.postgres.hex}"
}

output "app_service_plan_name" {
  value = "${var.prefix}-asp-${var.purpose}-${random_id.asp.hex}"
}

output "bastion_public_ip_name" {
  value = "${var.prefix}-pip-bastion-${random_id.bastion.hex}"
}

output "bastion_host_name" {
  value = "${var.prefix}-bastion-${random_id.bastion.hex}"
}

output "log_analytics_workspace_name" {
  value = "${var.prefix}-law-${var.purpose}-${random_id.law.hex}"
}

output "jumphost_nic_name" {
  value = "${var.prefix}-nic-jumphost-${random_id.jumphost.hex}"
}

output "jumphost_vm_name" {
  value = "${var.prefix}-vm-jumphost-${random_id.jumphost.hex}"
}

output "private_dns_zones" {
  value = {
    key_vault     = "privatelink.vaultcore.azure.net"
    postgres      = "privatelink.postgres.database.azure.com"
    storage_blob  = "privatelink.blob.core.windows.net"
    storage_queue = "privatelink.queue.core.windows.net"
    storage_table = "privatelink.table.core.windows.net"
    acr           = "privatelink.azurecr.io"
    app_service   = "privatelink.azurewebsites.net"
  }
}
