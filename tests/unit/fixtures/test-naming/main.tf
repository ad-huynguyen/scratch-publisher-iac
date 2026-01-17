terraform {
  required_version = ">= 1.5.0"
}

variable "metadata" {
  type = object({
    subscriptionId    = string
    resourceGroupName = string
    location          = string
  })
}

variable "parameters" {
  type = map(any)
}

module "naming" {
  source      = "__MODULE_DIR__"
  prefix      = var.parameters.system_name
  environment = "dev"
  purpose     = "publisher"
}
