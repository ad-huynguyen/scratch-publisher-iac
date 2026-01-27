output "key_vault_name" {
  value = azurerm_key_vault.this.name
}

output "private_endpoint_id" {
  value = azurerm_private_endpoint.kv.id
}

output "key_vault_id" {
  value = azurerm_key_vault.this.id
}

output "key_vault_uri" {
  description = "The URI of the Key Vault for secret references"
  value       = azurerm_key_vault.this.vault_uri
}
