variable "resource_group_name" {
  description = "Resource group name."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "storage_account_name" {
  description = "Storage account name."
  type        = string
}

variable "queue_name" {
  description = "Queue name."
  type        = string
}

variable "table_name" {
  description = "Table name."
  type        = string
}

variable "private_endpoint_subnet_id" {
  description = "Subnet ID for private endpoints."
  type        = string
}

variable "private_dns_zone_ids" {
  description = "Map of private DNS zone IDs for blob, queue, table."
  type        = map(string)
}
