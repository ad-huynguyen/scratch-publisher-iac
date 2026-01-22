resource "azurerm_public_ip" "pip" {
  name                = var.public_ip_name
  resource_group_name = var.resource_group_name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = []
}

resource "azurerm_bastion_host" "this" {
  name                = var.bastion_name
  resource_group_name = var.resource_group_name
  location            = var.location

  sku                = "Basic"
  copy_paste_enabled = true
  file_copy_enabled  = false
  ip_configuration {
    name                 = "configuration"
    subnet_id            = var.subnet_id
    public_ip_address_id = azurerm_public_ip.pip.id
  }
}
