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
    random = {
      source  = "hashicorp/random"
      version = ">= 3.6.2"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id      = var.subscription_id
  storage_use_azuread  = true
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

# PostgreSQL in westus with public endpoint (eastus restricted for this subscription)
# VNet integration requires same region, so using public endpoint mode with firewall rules
# NOTE (VD-130): Private DNS zone 'privatelink.postgres.database.azure.com' is created but not used
#   here because PostgreSQL is deployed to westus while VNet is in eastus. For prod environment
#   with unrestricted region, use: delegated_subnet_id = module.network.subnet_ids.postgres,
#   private_dns_zone_id = module.dns.zone_ids["postgres"], public_network_access = false
module "postgres" {
  source                 = "../../modules/postgres"
  resource_group_name    = azurerm_resource_group.rg.name
  location               = "westus"  # eastus restricted, westus available
  postgres_name          = module.naming.postgres_name
  delegated_subnet_id    = null      # No VNet integration (different region)
  private_dns_zone_id    = null      # No private DNS (public endpoint)
  public_network_access  = true      # Enable public endpoint with firewall
  administrator_login    = var.postgres_admin_login
  administrator_password = var.postgres_admin_password
  aad_tenant_id          = var.tenant_id
  aad_principal_id       = var.postgres_aad_principal_id
  aad_principal_name     = var.postgres_aad_principal_name
}

# App Service Plan - Blocked by Azure Policy "Dev/Test Cost Guardrails"
# Policy: /providers/Microsoft.Management/managementGroups/mg-devtest-guardrails/providers/Microsoft.Authorization/policyAssignments/dt-cost-guardrails
# Action: Request policy exemption or deploy in a different subscription
# module "app_service_plan" {
#   source              = "../../modules/appserviceplan"
#   resource_group_name = azurerm_resource_group.rg.name
#   location            = local.location
#   plan_name           = module.naming.app_service_plan_name
#   sku                 = "B1"  # Or use variable for environment-specific SKU
# }

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

resource "azurerm_monitor_diagnostic_setting" "storage" {
  name                       = "${module.naming.storage_account_name}-diag"
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
