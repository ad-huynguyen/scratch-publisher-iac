output "contributor_group_id" {
  description = "Object ID of the contributor AAD group"
  value       = azuread_group.contributor.object_id
}

output "reader_group_id" {
  description = "Object ID of the reader AAD group"
  value       = azuread_group.reader.object_id
}

output "db_operator_group_id" {
  description = "Object ID of the database operator AAD group"
  value       = azuread_group.db_operator.object_id
}

output "db_admin_group_id" {
  description = "Object ID of the database admin AAD group"
  value       = azuread_group.db_admin.object_id
}

output "group_names" {
  description = "Map of AAD group display names for documentation"
  value = {
    contributor = azuread_group.contributor.display_name
    reader      = azuread_group.reader.display_name
    db_operator = azuread_group.db_operator.display_name
    db_admin    = azuread_group.db_admin.display_name
  }
}

output "role_assignments" {
  description = "Map of role assignment IDs for auditability (SR-6)"
  value = {
    contributor_rg         = azurerm_role_assignment.contributor_rg.id
    reader_rg              = azurerm_role_assignment.reader_rg.id
    contributor_kv_secrets = azurerm_role_assignment.contributor_kv_secrets.id
    reader_kv_secrets      = azurerm_role_assignment.reader_kv_secrets.id
    contributor_storage    = azurerm_role_assignment.contributor_storage_blob.id
    reader_storage         = azurerm_role_assignment.reader_storage_blob.id
    contributor_acr        = azurerm_role_assignment.contributor_acr_push.id
    reader_acr             = azurerm_role_assignment.reader_acr_pull.id
  }
}
