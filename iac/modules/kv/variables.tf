variable "resource_group_name" {
  description = "Resource group name."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "key_vault_name" {
  description = "Key Vault name."
  type        = string
}

variable "tenant_id" {
  description = "Azure AD tenant ID."
  type        = string
}

variable "private_endpoint_subnet_id" {
  description = "Subnet ID for private endpoints."
  type        = string
}

variable "private_dns_zone_id" {
  description = "Private DNS zone ID for Key Vault."
  type        = string
}
