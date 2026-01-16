variable "prefix" {
  description = "Global prefix for all resources."
  type        = string
  default     = "vd"
}

variable "environment" {
  description = "Environment name (e.g., dev, prod, ephemeral)."
  type        = string
}

variable "purpose" {
  description = "Purpose qualifier for the deployment (e.g., publisher)."
  type        = string
  default     = "publisher"
}
