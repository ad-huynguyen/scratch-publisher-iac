output "storage_account_id" {
  value = azurerm_storage_account.this.id
}

output "queue_id" {
  value = azurerm_storage_queue.queue.id
}

output "table_id" {
  value = azurerm_storage_table.table.id
}
