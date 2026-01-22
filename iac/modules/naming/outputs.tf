output "resource_group_name" {
  value = "${local.resource_group_prefix}-${random_id.rg.hex}"
}

output "vnet_name" {
  value = "${var.prefix}-vnet-${random_id.network.hex}"
}

output "subnet_bastion_name" {
  value = "AzureBastionSubnet"
}

output "subnet_jumphost_name" {
  value = "snet-jumphost"
}

output "subnet_private_endpoints_name" {
  value = "snet-private-endpoints"
}

output "subnet_postgres_name" {
  value = "snet-postgres"
}

output "storage_account_name" {
  value = lower(replace("${var.prefix}st${random_id.storage.hex}", "/[^a-z0-9]/", ""))
}

output "storage_queue_name" {
  value = "publisher-queue"
}

output "storage_table_name" {
  value = "publishertable"
}

output "key_vault_name" {
  value = "${var.prefix}-kv-${random_id.kv.hex}"
}

output "acr_name" {
  value = "${var.prefix}acr${random_id.acr.hex}"
}

output "postgres_name" {
  value = "${var.prefix}-psql-${random_id.postgres.hex}"
}

output "app_service_plan_name" {
  value = "${var.prefix}-asp-${random_id.asp.hex}"
}

output "bastion_public_ip_name" {
  value = "${var.prefix}-pip-bastion-${random_id.bastion.hex}"
}

output "bastion_host_name" {
  value = "${var.prefix}-bastion-${random_id.bastion.hex}"
}

output "log_analytics_workspace_name" {
  value = "${var.prefix}-law-${random_id.law.hex}"
}

output "jumphost_nic_name" {
  value = "${var.prefix}-nic-jumphost-${random_id.jumphost.hex}"
}

output "jumphost_vm_name" {
  value = "${var.prefix}-vm-jumphost-${random_id.jumphost.hex}"
}

output "private_dns_zones" {
  value = {
    key_vault     = "privatelink.vaultcore.azure.net"
    postgres      = "privatelink.postgres.database.azure.com"
    storage_blob  = "privatelink.blob.core.windows.net"
    storage_queue = "privatelink.queue.core.windows.net"
    storage_table = "privatelink.table.core.windows.net"
    acr           = "privatelink.azurecr.io"
    app_service   = "privatelink.azurewebsites.net"
  }
}
