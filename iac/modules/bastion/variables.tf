variable "resource_group_name" {
  description = "Resource group name."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "bastion_name" {
  description = "Bastion host name."
  type        = string
}

variable "public_ip_name" {
  description = "Public IP name for Bastion."
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID for Bastion."
  type        = string
}
