# =============================================================================
# main.tf
# Infrastructure for azure-python-devops, built entirely from Azure
# free-tier / low-cost resources:
#   1. Resource Group            - free, just a logical container for billing/mgmt
#   2. Azure Container Registry  - Basic SKU, free for the first 12 months on
#                                  an Azure free account, then ~$0.167/day
#   3. Azure Container Instance  - runs the Docker image from ACR. ACI itself
#                                  is pay-as-you-go, but a new Azure free
#                                  account includes a 12-month/credit-backed
#                                  allowance, and staying at 1 vCPU / 1GB and
#                                  turning it off when unused keeps cost ~$0.
#                                  See README.md for the always-free App
#                                  Service F1 alternative.
# =============================================================================

terraform {
  required_version = ">= 1.5.0"

  backend "azurerm" {
    resource_group_name  = "terraform-backend-rg"
    storage_account_name = "tfstateraimadb"
    container_name       = "tfstate"
    key                  = "terraform.tfstate"
  }

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# -----------------------------------------------------------------------
# 1. Resource Group
# A logical container that holds all related Azure resources together.
# Deleting the resource group deletes everything inside it in one shot -
# this is the fastest way to guarantee $0 spend when you're done.
# -----------------------------------------------------------------------
resource "azurerm_resource_group" "main" {
  name     = "${var.project_name}-rg"
  location = var.location

  tags = {
    project     = var.project_name
    environment = var.environment
    managed_by  = "terraform"
  }
}

# -----------------------------------------------------------------------
# 2. Azure Container Registry (Basic SKU)
# A private Docker registry to store your built application images.
# Basic SKU is the cheapest tier and is free for 12 months under a new
# Azure free account. admin_enabled = true lets GitHub Actions push/pull
# using a simple username/password (stored as REGISTRY_USERNAME /
# REGISTRY_PASSWORD secrets) instead of a more complex service principal
# scoped to ACR.
# -----------------------------------------------------------------------
resource "azurerm_container_registry" "main" {
  # ACR names must be globally unique, alphanumeric only, 5-50 chars.
  name                = "${var.project_name}acr"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "Basic"
  admin_enabled       = true

  tags = {
    project     = var.project_name
    environment = var.environment
    managed_by  = "terraform"
  }
}

# -----------------------------------------------------------------------
# User-assigned managed identity for ACI to pull images from ACR without
# any password/credential ever being stored or output — Azure handles
# the authentication behind the scenes.
# -----------------------------------------------------------------------
resource "azurerm_user_assigned_identity" "aci_identity" {
  name                = "${var.project_name}-identity"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
}

resource "azurerm_role_assignment" "acr_pull" {
  scope                = azurerm_container_registry.main.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.aci_identity.principal_id
}

# -----------------------------------------------------------------------
# 3. Azure Container Instance (ACI)
# Runs your Docker container without needing a full VM or Kubernetes
# cluster (no AKS = no cluster management overhead or control-plane
# cost). 1 vCPU / 1GB RAM is the smallest practical size and keeps you
# well inside typical free-tier/credit allowances if you stop the
# container when it's not in use (see README "How to destroy").
# -----------------------------------------------------------------------
resource "azurerm_container_group" "main" {
  name                = "${var.project_name}-aci"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  os_type             = "Linux"
  restart_policy      = "OnFailure"

  # DNS name must be globally unique across all of Azure; combined with the
  # region this becomes the public FQDN, e.g.
  # azpydevops-app.centralindia.azurecontainer.io
  dns_name_label = "${var.project_name}-app"

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.aci_identity.id]
  }

  image_registry_credential {
    server                     = azurerm_container_registry.main.login_server
    user_assigned_identity_id  = azurerm_user_assigned_identity.aci_identity.id
  }

  container {
    name   = "${var.project_name}-container"
    image  = "${azurerm_container_registry.main.login_server}/${var.project_name}:${var.image_tag}"
    cpu    = var.container_cpu
    memory = var.container_memory

    ports {
      port     = var.container_port
      protocol = "TCP"
    }

    environment_variables = {
      ENVIRONMENT = var.environment
    }
  }

  tags = {
    project     = var.project_name
    environment = var.environment
    managed_by  = "terraform"
  }

  # The container image must already exist in ACR before Terraform can
  # start the container group, so ACR is created first.
  depends_on = [azurerm_container_registry.main, azurerm_role_assignment.acr_pull]
}
