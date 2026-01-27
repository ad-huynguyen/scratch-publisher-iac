variable "environment" {
  description = "Environment name (dev, prod) for group naming"
  type        = string
  validation {
    condition     = contains(["dev", "prod", "ephemeral"], var.environment)
    error_message = "Environment must be dev, prod, or ephemeral."
  }
}

variable "resource_group_id" {
  description = "The ID of the resource group for control plane role assignments"
  type        = string
}

variable "key_vault_id" {
  description = "The ID of the Key Vault for data plane role assignments"
  type        = string
}

variable "storage_account_id" {
  description = "The ID of the Storage Account for data plane role assignments"
  type        = string
}

variable "acr_id" {
  description = "The ID of the Container Registry for data plane role assignments"
  type        = string
}
