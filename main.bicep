targetScope = 'subscription'
param location string
@minLength(1)
@maxLength(90)
param resourceGroupName string
@minLength(1)
@maxLength(10)
param environmentName string
@minLength(1)
@maxLength(20)
param resourceSuffix string
param keyVaultCertificatesOfficerObjectId string

resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: resourceGroupName
  location: location
}

module workload 'main.resources.bicep' = {
  name: 'datasynchro-appgw-container'
  scope: resourceGroup(resourceGroupName)
  params: {
    location: location
    environmentName: environmentName
    resourceSuffix: resourceSuffix
    keyVaultCertificatesOfficerObjectId: keyVaultCertificatesOfficerObjectId
  }
  dependsOn: [
    rg
  ]
}

output AZURE_CONTAINER_REGISTRY_ENDPOINT string = workload.outputs.AZURE_CONTAINER_REGISTRY_ENDPOINT
output AZURE_AKS_CLUSTER_NAME string = workload.outputs.AZURE_AKS_CLUSTER_NAME
output AZURE_AGFC_ID string = workload.outputs.AZURE_AGFC_ID
output AZURE_ALB_IDENTITY_CLIENT_ID string = workload.outputs.AZURE_ALB_IDENTITY_CLIENT_ID
output AZURE_APP_IDENTITY_CLIENT_ID string = workload.outputs.AZURE_APP_IDENTITY_CLIENT_ID
output AZURE_KEY_VAULT_NAME string = workload.outputs.AZURE_KEY_VAULT_NAME
output AZURE_TENANT_ID string = workload.outputs.AZURE_TENANT_ID
