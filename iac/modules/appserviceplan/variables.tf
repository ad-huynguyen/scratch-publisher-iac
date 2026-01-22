variable "resource_group_name" {
  description = "Resource group name."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "plan_name" {
  description = "App Service Plan name."
  type        = string
}

variable "sku" {
  description = "App Service Plan SKU."
  type        = string
  default     = "B1"
}
