variable "resource_group_name" {
  description = "Resource group for DNS zones."
  type        = string
}

variable "zone_names" {
  description = "Map of private DNS zone names keyed by logical service key."
  type        = map(string)
}

variable "vnet_id" {
  description = "VNet ID to link."
  type        = string
}
