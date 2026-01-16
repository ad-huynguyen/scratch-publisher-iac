variable "location" {
  description = "Azure region for dev."
  type        = string
  default     = "eastus"
}

variable "system_name" {
  description = "System prefix (naming)."
  type        = string
  default     = "vd"
}

variable "owner" {
  description = "Owner tag value."
  type        = string
}

variable "subscription_id" {
  description = "Azure subscription ID."
  type        = string
}

variable "vnet_cidr" {
  description = "VNet CIDR (RFC1918)."
  type        = string
  default     = "10.10.0.0/16"
}

variable "subnet_bastion_cidr" {
  description = "CIDR for AzureBastionSubnet."
  type        = string
  default     = "10.10.0.0/27"
}

variable "subnet_jumphost_cidr" {
  description = "CIDR for JumpHost subnet."
  type        = string
  default     = "10.10.0.32/26"
}

variable "subnet_private_endpoints_cidr" {
  description = "CIDR for private endpoints subnet."
  type        = string
  default     = "10.10.1.0/28"
}

variable "subnet_postgres_cidr" {
  description = "CIDR for Postgres delegated subnet."
  type        = string
  default     = "10.10.2.0/27"
}

variable "tenant_id" {
  description = "AAD tenant ID."
  type        = string
}

variable "postgres_admin_login" {
  description = "Bootstrap admin login (AAD-only recommended)."
  type        = string
}

variable "postgres_admin_password" {
  description = "Bootstrap admin password."
  type        = string
  sensitive   = true
}

variable "postgres_aad_principal_id" {
  description = "AAD object ID for Postgres administrator."
  type        = string
}

variable "postgres_aad_principal_name" {
  description = "Display name for Postgres administrator principal."
  type        = string
}

variable "jumphost_admin_username" {
  description = "JumpHost admin username."
  type        = string
}

variable "jumphost_ssh_public_key" {
  description = "JumpHost SSH public key."
  type        = string
}

variable "additional_tags" {
  description = "Optional additional tags."
  type        = map(string)
  default     = {}
}
