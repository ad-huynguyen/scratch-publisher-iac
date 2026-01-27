terraform {
  required_version = ">= 1.5.0"

  backend "azurerm" {
    // Override all values via -backend-config to comply with RFC-80:
    // resource_group_name, storage_account_name, container_name (tfstate-nonprod), key (publisher/vd-core/dev/<env_id>/terraform.tfstate)
    resource_group_name  = "vd-rg-tfstate-j5y324me"
    storage_account_name = "vdsttfstatej5y324me"
    container_name       = "tfstate-nonprod"
    key                  = "publisher/vd-core/dev/dev/terraform.tfstate"
  }

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.90.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = ">= 2.47.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.6.2"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id     = var.subscription_id
  storage_use_azuread = true
}

provider "azuread" {
  tenant_id = var.tenant_id
}

locals {
  prefix      = var.system_name
  environment = "dev"
  purpose     = "publisher"

  location = var.location

  address_space               = [var.vnet_cidr]
  subnet_bastion_prefix       = var.subnet_bastion_cidr
  subnet_jumphost_prefix      = var.subnet_jumphost_cidr
  subnet_private_endpt_prefix = var.subnet_private_endpoints_cidr
  subnet_postgres_prefix      = var.subnet_postgres_cidr

  tags = {
    environment = local.environment
    purpose     = "publisher"
    owner       = var.owner
  }
}

module "naming" {
  source      = "../../modules/naming"
  prefix      = local.prefix
  environment = local.environment
  purpose     = local.purpose
}

resource "azurerm_resource_group" "rg" {
  name     = module.naming.resource_group_name
  location = local.location
  tags     = local.tags
}

module "network" {
  source                          = "../../modules/network"
  resource_group_name             = azurerm_resource_group.rg.name
  location                        = local.location
  vnet_name                       = module.naming.vnet_name
  address_space                   = local.address_space
  subnet_bastion_name             = module.naming.subnet_bastion_name
  subnet_bastion_prefix           = local.subnet_bastion_prefix
  subnet_jumphost_name            = module.naming.subnet_jumphost_name
  subnet_jumphost_prefix          = local.subnet_jumphost_prefix
  subnet_private_endpoints_name   = module.naming.subnet_private_endpoints_name
  subnet_private_endpoints_prefix = local.subnet_private_endpt_prefix
  subnet_postgres_name            = module.naming.subnet_postgres_name
  subnet_postgres_prefix          = local.subnet_postgres_prefix
}

module "dns" {
  source              = "../../modules/dns"
  resource_group_name = azurerm_resource_group.rg.name
  vnet_id             = module.network.vnet_id
  zone_names          = module.naming.private_dns_zones
}

module "key_vault" {
  source                     = "../../modules/kv"
  resource_group_name        = azurerm_resource_group.rg.name
  location                   = local.location
  key_vault_name             = module.naming.key_vault_name
  tenant_id                  = var.tenant_id
  private_endpoint_subnet_id = module.network.subnet_ids.private_endpoints
  private_dns_zone_id        = module.dns.zone_ids["key_vault"]
}

module "storage" {
  source                     = "../../modules/storage"
  resource_group_name        = azurerm_resource_group.rg.name
  location                   = local.location
  storage_account_name       = module.naming.storage_account_name
  queue_name                 = module.naming.storage_queue_name
  table_name                 = module.naming.storage_table_name
  private_endpoint_subnet_id = module.network.subnet_ids.private_endpoints
  private_dns_zone_ids = {
    blob  = module.dns.zone_ids["storage_blob"]
    queue = module.dns.zone_ids["storage_queue"]
    table = module.dns.zone_ids["storage_table"]
  }
}

module "acr" {
  source                     = "../../modules/acr"
  resource_group_name        = azurerm_resource_group.rg.name
  location                   = local.location
  acr_name                   = module.naming.acr_name
  private_endpoint_subnet_id = module.network.subnet_ids.private_endpoints
  private_dns_zone_id        = module.dns.zone_ids["acr"]
}

# PostgreSQL with private endpoint per RFC-71 Section 5.1 and PRD-46 SR-5
module "postgres" {
  source                 = "../../modules/postgres"
  resource_group_name    = azurerm_resource_group.rg.name
  location               = local.location
  postgres_name          = module.naming.postgres_name
  delegated_subnet_id    = module.network.subnet_ids.postgres
  private_dns_zone_id    = module.dns.zone_ids["postgres"]
  public_network_access  = false
  administrator_login    = var.postgres_admin_login
  administrator_password = var.postgres_admin_password
  aad_tenant_id          = var.tenant_id
  aad_principal_id       = var.postgres_aad_principal_id
  aad_principal_name     = var.postgres_aad_principal_name
  # db-admin group as PostgreSQL AAD administrator (RBAC-7, VD-133)
  enable_db_admin_group = true
  db_admin_group_id     = module.rbac.db_admin_group_id
  db_admin_group_name   = module.rbac.group_names.db_admin
}

# App Service Plan per RFC-71 Section 7.2 (P1v3 minimum for VNet integration)
module "app_service_plan" {
  source              = "../../modules/appserviceplan"
  resource_group_name = azurerm_resource_group.rg.name
  location            = local.location
  plan_name           = module.naming.app_service_plan_name
  sku                 = "P1v3"
}

module "bastion" {
  source              = "../../modules/bastion"
  resource_group_name = azurerm_resource_group.rg.name
  location            = local.location
  bastion_name        = module.naming.bastion_host_name
  public_ip_name      = module.naming.bastion_public_ip_name
  subnet_id           = module.network.subnet_ids.bastion
}

module "jumphost" {
  source              = "../../modules/vm-jumphost"
  resource_group_name = azurerm_resource_group.rg.name
  location            = local.location
  nic_name            = module.naming.jumphost_nic_name
  vm_name             = module.naming.jumphost_vm_name
  subnet_id           = module.network.subnet_ids.jumphost
  vm_size             = "Standard_D2s_v3"
  admin_username      = var.jumphost_admin_username
  ssh_public_key      = var.jumphost_ssh_public_key
}

module "log_analytics" {
  source              = "../../modules/log-analytics"
  resource_group_name = azurerm_resource_group.rg.name
  location            = local.location
  workspace_name      = module.naming.log_analytics_workspace_name
  retention_in_days   = 30 # Azure minimum is 30 days (SR-7 7-day requirement not achievable with LAW)
}

# Diagnostics to Log Analytics Workspace (RFC-71 / PRD-46)
resource "azurerm_monitor_diagnostic_setting" "kv" {
  name                       = "${module.naming.key_vault_name}-diag"
  target_resource_id         = module.key_vault.key_vault_id
  log_analytics_workspace_id = module.log_analytics.workspace_id

  enabled_log {
    category = "AuditEvent"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}

resource "azurerm_monitor_diagnostic_setting" "storage_blob" {
  name                       = "${module.naming.storage_account_name}-blob-diag"
  target_resource_id         = "${module.storage.storage_account_id}/blobServices/default"
  log_analytics_workspace_id = module.log_analytics.workspace_id

  enabled_log {
    category = "StorageRead"
  }

  enabled_log {
    category = "StorageWrite"
  }

  enabled_log {
    category = "StorageDelete"
  }

  enabled_metric {
    category = "Capacity"
  }

  enabled_metric {
    category = "Transaction"
  }
}

resource "azurerm_monitor_diagnostic_setting" "storage_queue" {
  name                       = "${module.naming.storage_account_name}-queue-diag"
  target_resource_id         = "${module.storage.storage_account_id}/queueServices/default"
  log_analytics_workspace_id = module.log_analytics.workspace_id

  enabled_log {
    category = "StorageRead"
  }

  enabled_log {
    category = "StorageWrite"
  }

  enabled_log {
    category = "StorageDelete"
  }

  enabled_metric {
    category = "Transaction"
  }
}

resource "azurerm_monitor_diagnostic_setting" "storage_table" {
  name                       = "${module.naming.storage_account_name}-table-diag"
  target_resource_id         = "${module.storage.storage_account_id}/tableServices/default"
  log_analytics_workspace_id = module.log_analytics.workspace_id

  enabled_log {
    category = "StorageRead"
  }

  enabled_log {
    category = "StorageWrite"
  }

  enabled_log {
    category = "StorageDelete"
  }

  enabled_metric {
    category = "Transaction"
  }
}

resource "azurerm_monitor_diagnostic_setting" "acr" {
  name                       = "${module.naming.acr_name}-diag"
  target_resource_id         = module.acr.acr_id
  log_analytics_workspace_id = module.log_analytics.workspace_id

  enabled_log {
    category = "ContainerRegistryRepositoryEvents"
  }

  enabled_log {
    category = "ContainerRegistryLoginEvents"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}

resource "azurerm_monitor_diagnostic_setting" "postgres" {
  name                       = "${module.naming.postgres_name}-diag"
  target_resource_id         = module.postgres.postgres_id
  log_analytics_workspace_id = module.log_analytics.workspace_id

  enabled_log {
    category = "PostgreSQLLogs"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}

resource "azurerm_monitor_diagnostic_setting" "bastion" {
  name                       = "${module.naming.bastion_host_name}-diag"
  target_resource_id         = module.bastion.bastion_id
  log_analytics_workspace_id = module.log_analytics.workspace_id

  enabled_log {
    category = "BastionAuditLogs"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}

# JumpHost VM diagnostics - platform metrics only (guest logs require AMA extension)
resource "azurerm_monitor_diagnostic_setting" "jumphost" {
  name                       = "${module.naming.jumphost_vm_name}-diag"
  target_resource_id         = module.jumphost.vm_id
  log_analytics_workspace_id = module.log_analytics.workspace_id

  enabled_metric {
    category = "AllMetrics"
  }
}

# Azure Policy assignments per PRD-46 Section 4.4 (POL-1, POL-2, POL-3)
module "policy" {
  source            = "../../modules/policy"
  resource_group_id = azurerm_resource_group.rg.id
  enforce           = false # Audit mode for initial deployment
}

# RBAC via AAD groups per PRD-46 Section 4.4 (RBAC-1 through RBAC-7)
module "rbac" {
  source             = "../../modules/rbac"
  environment        = local.environment
  resource_group_id  = azurerm_resource_group.rg.id
  key_vault_id       = module.key_vault.key_vault_id
  storage_account_id = module.storage.storage_account_id
  acr_id             = module.acr.acr_id
}

# -----------------------------------------------------------------------------
# Database RBAC and Admin Setup (VD-133, PRD-46 FR-11, RBAC-7)
# -----------------------------------------------------------------------------

# Store PostgreSQL admin password in Key Vault (FR-11)
resource "azurerm_key_vault_secret" "postgres_admin_password" {
  name         = "postgres-admin-password"
  value        = var.postgres_admin_password
  key_vault_id = module.key_vault.key_vault_id
  content_type = "text/plain"

  tags = merge(local.tags, {
    purpose = "PostgreSQL administrator password"
  })

  # Ensure RBAC permissions are in place before creating secret
  depends_on = [module.rbac]
}
