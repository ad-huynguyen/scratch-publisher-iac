# RBAC Module for PRD-46 Section 4.4 (RBAC-1 through RBAC-7)
# Creates AAD groups and assigns control plane + data plane roles

# -----------------------------------------------------------------------------
# AAD Security Groups (RBAC-1 through RBAC-4)
# Groups: publisher-{env}-contributor, publisher-{env}-reader
# DB groups (db-operator, db-admin) are created but not assigned roles here
# -----------------------------------------------------------------------------

resource "azuread_group" "contributor" {
  display_name     = "publisher-${var.environment}-contributor"
  description      = "Infrastructure operators for publisher ${var.environment} environment"
  security_enabled = true
}

resource "azuread_group" "reader" {
  display_name     = "publisher-${var.environment}-reader"
  description      = "Read-only access for publisher ${var.environment} environment"
  security_enabled = true
}

resource "azuread_group" "db_operator" {
  display_name     = "publisher-${var.environment}-db-operator"
  description      = "Database read/write operators for publisher ${var.environment} environment"
  security_enabled = true
}

resource "azuread_group" "db_admin" {
  display_name     = "publisher-${var.environment}-db-admin"
  description      = "Database administrators (DBO) for publisher ${var.environment} environment"
  security_enabled = true
}

# -----------------------------------------------------------------------------
# Control Plane RBAC (RBAC-5)
# Contributor and Reader roles at resource group level
# -----------------------------------------------------------------------------

resource "azurerm_role_assignment" "contributor_rg" {
  scope                = var.resource_group_id
  role_definition_name = "Contributor"
  principal_id         = azuread_group.contributor.object_id
}

resource "azurerm_role_assignment" "reader_rg" {
  scope                = var.resource_group_id
  role_definition_name = "Reader"
  principal_id         = azuread_group.reader.object_id
}

# -----------------------------------------------------------------------------
# Data Plane RBAC - Key Vault (RBAC-6)
# Contributor: Key Vault Secrets Officer
# Reader: Key Vault Secrets User
# -----------------------------------------------------------------------------

resource "azurerm_role_assignment" "contributor_kv_secrets" {
  scope                = var.key_vault_id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = azuread_group.contributor.object_id
}

resource "azurerm_role_assignment" "reader_kv_secrets" {
  scope                = var.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azuread_group.reader.object_id
}

# -----------------------------------------------------------------------------
# Data Plane RBAC - Storage Account (RBAC-6)
# Contributor: Storage Blob Data Contributor
# Reader: Storage Blob Data Reader
# -----------------------------------------------------------------------------

resource "azurerm_role_assignment" "contributor_storage_blob" {
  scope                = var.storage_account_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azuread_group.contributor.object_id
}

resource "azurerm_role_assignment" "reader_storage_blob" {
  scope                = var.storage_account_id
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = azuread_group.reader.object_id
}

# -----------------------------------------------------------------------------
# Data Plane RBAC - ACR (RBAC-6)
# Contributor: AcrPush
# Reader: AcrPull
# -----------------------------------------------------------------------------

resource "azurerm_role_assignment" "contributor_acr_push" {
  scope                = var.acr_id
  role_definition_name = "AcrPush"
  principal_id         = azuread_group.contributor.object_id
}

resource "azurerm_role_assignment" "reader_acr_pull" {
  scope                = var.acr_id
  role_definition_name = "AcrPull"
  principal_id         = azuread_group.reader.object_id
}

# -----------------------------------------------------------------------------
# PostgreSQL RBAC is handled via AAD integration in the postgres module
# The db_operator and db_admin groups can be added to PostgreSQL AAD auth
# after initial deployment (RBAC-7)
# -----------------------------------------------------------------------------
