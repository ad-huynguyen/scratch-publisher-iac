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
  description = "Private DNS zone ID for Postgres (required for VNet integration)."
  type        = string
  default     = null
}

variable "delegated_subnet_id" {
  description = "Delegated subnet for the Flexible Server (null for public endpoint mode)."
  type        = string
  default     = null
}

variable "public_network_access" {
  description = "Enable public network access (required when delegated_subnet_id is null)."
  type        = bool
  default     = false
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

variable "zone" {
  description = "Availability zone for the PostgreSQL server."
  type        = string
  default     = "1"
}

# -----------------------------------------------------------------------------
# Database RBAC - db-admin group (RBAC-7, VD-133)
# -----------------------------------------------------------------------------

variable "enable_db_admin_group" {
  description = "Enable db-admin AAD group as PostgreSQL administrator."
  type        = bool
  default     = false
}

variable "db_admin_group_id" {
  description = "AAD object ID for the db-admin group (PostgreSQL AAD administrator)."
  type        = string
  default     = ""
}

variable "db_admin_group_name" {
  description = "Display name for the db-admin AAD group."
  type        = string
  default     = ""
}
