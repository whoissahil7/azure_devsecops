# =============================================================================
# outputs.tf
# Values printed after `terraform apply` / consumed by GitHub Actions.
# =============================================================================

output "resource_group_name" {
  description = "Name of the resource group holding all resources."
  value       = azurerm_resource_group.main.name
}

output "acr_login_server" {
  description = "ACR login server, e.g. azpydevopsacr.azurecr.io - used by `docker push` and by the ACI image reference."
  value       = azurerm_container_registry.main.login_server
}

output "acr_admin_username" {
  description = "ACR admin username, used for docker/azure login (store as REGISTRY_USERNAME secret)."
  value       = azurerm_container_registry.main.admin_username
}

output "aci_fqdn" {
  description = "Public fully-qualified domain name of the running container. Visit http://<this>:8000 and http://<this>:8000/health once deployed."
  value       = azurerm_container_group.main.fqdn
}

output "aci_ip_address" {
  description = "Public IP address of the container group."
  value       = azurerm_container_group.main.ip_address
}
