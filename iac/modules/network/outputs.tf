output "vnet_id" {
  value = azurerm_virtual_network.this.id
}

output "subnet_ids" {
  value = {
    bastion           = azurerm_subnet.bastion.id
    jumphost          = azurerm_subnet.jumphost.id
    private_endpoints = azurerm_subnet.private_endpoints.id
    postgres          = azurerm_subnet.postgres.id
  }
}
