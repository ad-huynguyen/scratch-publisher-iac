output "policy_assignment_ids" {
  description = "Map of policy assignment IDs"
  value = {
    kv_private_endpoint       = azurerm_resource_group_policy_assignment.kv_private_endpoint.id
    storage_private_endpoint  = azurerm_resource_group_policy_assignment.storage_private_endpoint.id
    acr_private_endpoint      = azurerm_resource_group_policy_assignment.acr_private_endpoint.id
    postgres_private_endpoint = azurerm_resource_group_policy_assignment.postgres_private_endpoint.id
    kv_deny_public            = azurerm_resource_group_policy_assignment.kv_deny_public.id
    storage_deny_public       = azurerm_resource_group_policy_assignment.storage_deny_public.id
    acr_deny_public           = azurerm_resource_group_policy_assignment.acr_deny_public.id
    require_tag_environment   = azurerm_resource_group_policy_assignment.require_tag_environment.id
    require_tag_owner         = azurerm_resource_group_policy_assignment.require_tag_owner.id
    require_tag_purpose       = azurerm_resource_group_policy_assignment.require_tag_purpose.id
  }
}
