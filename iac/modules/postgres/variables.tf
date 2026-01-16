variable "resource_group_name" {
  description = "Resource group name."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "postgres_name" {
  description = "PostgreSQL Flexible Server name."
  type        = string
}

variable "private_dns_zone_id" {
  description = "Private DNS zone ID for Postgres."
  type        = string
}

variable "delegated_subnet_id" {
  description = "Delegated subnet for the Flexible Server."
  type        = string
}

variable "administrator_login" {
  description = "Administrator login (used only for bootstrap; recommend disabling password auth)."
  type        = string
}

variable "administrator_password" {
  description = "Administrator password."
  type        = string
  sensitive   = true
}

variable "aad_tenant_id" {
  description = "AAD tenant ID."
  type        = string
}

variable "aad_principal_id" {
  description = "AAD object ID for Postgres administrator (e.g., group or app)."
  type        = string
}

variable "aad_principal_name" {
  description = "Display name for the AAD administrator."
  type        = string
}
