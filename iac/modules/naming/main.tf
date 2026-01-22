terraform {
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = ">= 3.6.2"
    }
  }
}

locals {
  # RG includes purpose to identify the deployment context
  resource_group_prefix = "${var.prefix}-rg-${var.purpose}"
  # Individual resources don't need purpose since RG already identifies context (RFC-71)
}

# Deterministic per-resource nanoids (keepers lock to env + purpose).
resource "random_id" "rg" {
  byte_length = 4 # 8 hex chars
  keepers = {
    environment = var.environment
    purpose     = var.purpose
    scope       = "rg"
  }
}

resource "random_id" "kv" {
  byte_length = 4 # 8 hex chars to keep name <= 24 chars for Azure Key Vault
  keepers = {
    environment = var.environment
    purpose     = var.purpose
    scope       = "kv"
  }
}

resource "random_id" "acr" {
  byte_length = 8
  keepers = {
    environment = var.environment
    purpose     = var.purpose
    scope       = "acr"
  }
}

resource "random_id" "storage" {
  byte_length = 4
  keepers = {
    environment = var.environment
    purpose     = var.purpose
    scope       = "storage"
  }
}

resource "random_id" "postgres" {
  byte_length = 8
  keepers = {
    environment = var.environment
    purpose     = var.purpose
    scope       = "postgres"
  }
}

resource "random_id" "asp" {
  byte_length = 6
  keepers = {
    environment = var.environment
    purpose     = var.purpose
    scope       = "asp"
  }
}

resource "random_id" "network" {
  byte_length = 6
  keepers = {
    environment = var.environment
    purpose     = var.purpose
    scope       = "vnet"
  }
}

resource "random_id" "bastion" {
  byte_length = 4
  keepers = {
    environment = var.environment
    purpose     = var.purpose
    scope       = "bastion"
  }
}

resource "random_id" "jumphost" {
  byte_length = 4
  keepers = {
    environment = var.environment
    purpose     = var.purpose
    scope       = "jumphost"
  }
}

resource "random_id" "law" {
  byte_length = 4
  keepers = {
    environment = var.environment
    purpose     = var.purpose
    scope       = "law"
  }
}
