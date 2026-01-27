# Azure Policy Module for PRD-46 Section 4.4 (POL-1, POL-2, POL-3)
# Enforces private endpoints, denies public access, and requires tagging

# -----------------------------------------------------------------------------
# POL-1: Enforce Private Endpoint Requirements
# Uses built-in policy definitions for Key Vault, Storage, ACR, PostgreSQL
# -----------------------------------------------------------------------------

# Key Vault - Configure with private endpoints
resource "azurerm_resource_group_policy_assignment" "kv_private_endpoint" {
  name                 = "kv-require-pe"
  resource_group_id    = var.resource_group_id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/a6abeaec-4d90-4a02-805f-6b26c4d3fbe9"
  display_name         = "Key Vault should use private link"
  description          = "POL-1: Audit Key Vault for private endpoint configuration"
  enforce              = var.enforce
}

# Storage Account - Configure with private endpoints
resource "azurerm_resource_group_policy_assignment" "storage_private_endpoint" {
  name                 = "storage-require-pe"
  resource_group_id    = var.resource_group_id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/6edd7eda-6dd8-40f7-810d-67160c639cd9"
  display_name         = "Storage accounts should use private link"
  description          = "POL-1: Audit Storage Account for private endpoint configuration"
  enforce              = var.enforce
}

# ACR - Configure with private endpoints
resource "azurerm_resource_group_policy_assignment" "acr_private_endpoint" {
  name                 = "acr-require-pe"
  resource_group_id    = var.resource_group_id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/e8eef0a8-67cf-4eb4-9386-14b0e78733d4"
  display_name         = "Container registries should use private link"
  description          = "POL-1: Audit ACR for private endpoint configuration"
  enforce              = var.enforce
}

# PostgreSQL Flexible Server - Configure with private endpoints (VNet integration)
resource "azurerm_resource_group_policy_assignment" "postgres_private_endpoint" {
  name                 = "postgres-require-pe"
  resource_group_id    = var.resource_group_id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/fdccbe47-f3e3-4213-ad5d-ea459b2fa077"
  display_name         = "PostgreSQL Flexible Server should have private network access"
  description          = "POL-1: Audit PostgreSQL for private endpoint/VNet configuration"
  enforce              = var.enforce
}

# -----------------------------------------------------------------------------
# POL-2: Deny Public Network Access
# Uses built-in policy definitions to deny public access
# -----------------------------------------------------------------------------

# Key Vault - Deny public network access
resource "azurerm_resource_group_policy_assignment" "kv_deny_public" {
  name                 = "kv-deny-public"
  resource_group_id    = var.resource_group_id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/405c5871-3e91-4644-8a63-58e19d68ff5b"
  display_name         = "Azure Key Vault should disable public network access"
  description          = "POL-2: Audit Key Vault public network access"
  enforce              = var.enforce
}

# Storage Account - Deny public network access
resource "azurerm_resource_group_policy_assignment" "storage_deny_public" {
  name                 = "storage-deny-public"
  resource_group_id    = var.resource_group_id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/b2982f36-99f2-4db5-8eff-283140c09693"
  display_name         = "Storage accounts should disable public network access"
  description          = "POL-2: Audit Storage Account public network access"
  enforce              = var.enforce
}

# ACR - Deny public network access
resource "azurerm_resource_group_policy_assignment" "acr_deny_public" {
  name                 = "acr-deny-public"
  resource_group_id    = var.resource_group_id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/0fdf0491-d080-4575-b627-ad0e843cba0f"
  display_name         = "Container registries should not allow unrestricted network access"
  description          = "POL-2: Audit ACR public network access"
  enforce              = var.enforce
}

# PostgreSQL - Public network access disabled (already covered by private endpoint policy)
# PostgreSQL Flexible Server with VNet integration has no public endpoint by design

# -----------------------------------------------------------------------------
# POL-3: Enforce Tagging Requirements (RFC-71 Section 20)
# Required tags: environment, owner, purpose
# Note: 'created' tag is dynamic and enforced at deployment time, not by policy
# -----------------------------------------------------------------------------

# Require 'environment' tag
resource "azurerm_resource_group_policy_assignment" "require_tag_environment" {
  name                 = "require-tag-env"
  resource_group_id    = var.resource_group_id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/871b6d14-10aa-478d-b590-94f262ecfa99"
  display_name         = "Require environment tag on resources"
  description          = "POL-3: Require 'environment' tag per RFC-71 Section 20"
  enforce              = var.enforce

  parameters = jsonencode({
    tagName = { value = "environment" }
  })
}

# Require 'owner' tag
resource "azurerm_resource_group_policy_assignment" "require_tag_owner" {
  name                 = "require-tag-owner"
  resource_group_id    = var.resource_group_id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/871b6d14-10aa-478d-b590-94f262ecfa99"
  display_name         = "Require owner tag on resources"
  description          = "POL-3: Require 'owner' tag per RFC-71 Section 20"
  enforce              = var.enforce

  parameters = jsonencode({
    tagName = { value = "owner" }
  })
}

# Require 'purpose' tag
resource "azurerm_resource_group_policy_assignment" "require_tag_purpose" {
  name                 = "require-tag-purpose"
  resource_group_id    = var.resource_group_id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/871b6d14-10aa-478d-b590-94f262ecfa99"
  display_name         = "Require purpose tag on resources"
  description          = "POL-3: Require 'purpose' tag per RFC-71 Section 20"
  enforce              = var.enforce

  parameters = jsonencode({
    tagName = { value = "purpose" }
  })
}
