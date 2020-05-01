resource "random_id" "entitlement_key" {
  byte_length = 18
}

module "keyvault" {
  source              = "../../../../modules/providers/azure/keyvault"
  keyvault_name       = local.kv_name
  resource_group_name = azurerm_resource_group.aks_rg.name
}

module "aks_keyvault_ssl_cert_import" {
  source                         = "../../../../modules/providers/azure/keyvault-cert"
  key_vault_cert_import_filepath = var.ssl_certificate_file
  keyvault_id                    = module.keyvault.keyvault_id
  key_vault_cert_name            = "appgw-ssl-cert"
}

module "aks_msi_keyvault_access_policy" {
  source    = "../../../../modules/providers/azure/keyvault-policy"
  vault_id  = module.keyvault.keyvault_id
  tenant_id = local.tenant_id
  object_ids = [
    module.app_management_service_principal.service_principal_object_id
  ]
  key_permissions         = ["get", "list"]
  secret_permissions      = ["get", "list"]
  certificate_permissions = ["get", "list", "import"]
}

locals {
  secrets_map = {
    # AAD Application Secrets
    aad-client-id = module.ad_application.azuread_app_ids[0]
    # App Insights Secrets
    appinsights-key = module.app_insights.app_insights_instrumentation_key
    # Service Bus Namespace Secrets
    sb-connection = module.service_bus.service_bus_namespace_default_connection_string
    # Elastic Search Cluster Secrets
    elastic-endpoint = data.terraform_remote_state.data_sources.outputs.elastic_cluster_properties.elastic_search.endpoint
    elastic-username = data.terraform_remote_state.data_sources.outputs.elastic_cluster_properties.elastic_search.username
    elastic-password = data.terraform_remote_state.data_sources.outputs.elastic_cluster_properties.elastic_search.password
    # Cosmos Cluster Secrets
    cosmos-endpoint    = data.terraform_remote_state.data_sources.outputs.cosmosdb_properties.cosmosdb.endpoint
    cosmos-primary-key = data.terraform_remote_state.data_sources.outputs.cosmosdb_properties.cosmosdb.primary_master_key
    cosmos-connection  = data.terraform_remote_state.data_sources.outputs.cosmosdb_properties.cosmosdb.connection_strings[0]
    # App Service Auth Related Secrets
    entitlement-key = random_id.entitlement_key.hex
    # Service Principal Secrets
    app-dev-sp-username  = module.app_management_service_principal.service_principal_application_id
    app-dev-sp-password  = module.app_management_service_principal.service_principal_password
    app-dev-sp-tenant-id = data.azurerm_client_config.current.tenant_id
    # App Gateway AAD Pod Identity Secrets
    aks-app-gw-msi-client-id   = module.aks-gitops.kubelet_client_id
    aks-app-gw-msi-resource-id = module.aks-gitops.kubelet_resource_id
  }

  output_secret_map = {
    for secret in module.keyvault_secrets.keyvault_secret_attributes :
    secret.name => secret.id
  }
}

module "keyvault_secrets" {
  source      = "../../../../modules/providers/azure/keyvault-secret"
  keyvault_id = module.keyvault.keyvault_id
  secrets     = local.secrets_map
}
