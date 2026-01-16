variable "resource_group_name" {
  description = "Resource group name."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "nic_name" {
  description = "Network interface name."
  type        = string
}

variable "vm_name" {
  description = "Virtual machine name."
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID for the VM."
  type        = string
}

variable "vm_size" {
  description = "VM size."
  type        = string
  default     = "Standard_B2s"
}

variable "admin_username" {
  description = "Admin username."
  type        = string
}

variable "ssh_public_key" {
  description = "SSH public key."
  type        = string
}
