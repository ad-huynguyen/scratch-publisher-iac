variable "resource_group_name" {
  description = "Target resource group for network resources."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "vnet_name" {
  description = "Virtual network name."
  type        = string
}

variable "address_space" {
  description = "Address space for the VNet."
  type        = list(string)
}

variable "subnet_bastion_name" {
  description = "Subnet name for Bastion."
  type        = string
  default     = "AzureBastionSubnet"
}

variable "subnet_bastion_prefix" {
  description = "Address prefix for Bastion subnet."
  type        = string
}

variable "subnet_jumphost_name" {
  description = "Subnet name for JumpHost."
  type        = string
  default     = "snet-jumphost"
}

variable "subnet_jumphost_prefix" {
  description = "Address prefix for JumpHost subnet."
  type        = string
}

variable "subnet_private_endpoints_name" {
  description = "Subnet name for private endpoints."
  type        = string
  default     = "snet-private-endpoints"
}

variable "subnet_private_endpoints_prefix" {
  description = "Address prefix for private endpoints subnet."
  type        = string
}

variable "subnet_postgres_name" {
  description = "Subnet name for Postgres Flexible Server."
  type        = string
  default     = "snet-postgres"
}

variable "subnet_postgres_prefix" {
  description = "Address prefix for Postgres Flexible Server subnet."
  type        = string
}
