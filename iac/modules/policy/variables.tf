variable "resource_group_id" {
  description = "The ID of the resource group to assign policies to"
  type        = string
}

variable "enforce" {
  description = "Whether to enforce the policy (true) or audit only (false)"
  type        = bool
  default     = false # Default to audit mode for initial deployment
}
