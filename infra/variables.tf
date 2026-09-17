# =============================================================================
# variables.tf
# Every input the Terraform config needs. Sensible free-tier-friendly
# defaults are provided so `terraform apply` works out of the box, but all
# of these can be overridden with -var or a .tfvars file / CI env vars.
# =============================================================================

variable "project_name" {
  description = "Short name used as a prefix for every Azure resource (letters/numbers only recommended, since ACR names must be globally unique alphanumeric)."
  type        = string
  default     = "azpydevops"
}

variable "location" {
  description = "Azure region to deploy into. centralindia is used here because it is the closest Azure region to Bangalore, minimizing latency."
  type        = string
  default     = "centralindia"
}

variable "environment" {
  description = "Deployment environment tag (e.g. dev, staging, prod). Used only for tagging/naming, not for creating separate infra."
  type        = string
  default     = "dev"
}

variable "image_tag" {
  description = "Docker image tag to deploy to Azure Container Instances. The GitHub Actions pipeline overrides this with the Git SHA on every push so each deploy is traceable to a commit."
  type        = string
  default     = "latest"
}

variable "container_cpu" {
  description = "vCPU cores allocated to the Azure Container Instance. Kept at 1 to stay within the smallest billable ACI size and to respect the free-tier vCPU-second budget."
  type        = number
  default     = 1
}

variable "container_memory" {
  description = "Memory (in GB) allocated to the Azure Container Instance."
  type        = number
  default     = 1
}

variable "container_port" {
  description = "Port the FastAPI app listens on inside the container (must match EXPOSE in the Dockerfile)."
  type        = number
  default     = 8000
}
