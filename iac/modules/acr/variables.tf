variable "resource_group_name" {
  description = "Resource group name."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "acr_name" {
  description = "ACR name."
  type        = string
}

variable "private_endpoint_subnet_id" {
  description = "Subnet ID for private endpoints."
  type        = string
}

variable "private_dns_zone_id" {
  description = "Private DNS zone ID for ACR."
  type        = string
}
