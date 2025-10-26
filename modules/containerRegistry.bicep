// Parameters
@description('Name of your Azure Container Registry')
@minLength(5)
@maxLength(50)
param name string 

@description('Enable admin user that have push / pull permission to the registry.')
param adminUserEnabled bool = false

@description('Specifies the resource id of the Log Analytics workspace.')
param workspaceId string

@description('Tier of your Azure Container Registry.')
@allowed([
  'Basic'
  'Standard'
  'Premium'
])
param sku string = 'Premium'


param kubeletidentityObjectId string

@description('Specifies the location.')
param location string 

@description('Specifies the resource tags.')
param tags object

var diagnosticSettingsName = 'diagnosticSettings'
var logCategories = [
  'ContainerRegistryRepositoryEvents'
  'ContainerRegistryLoginEvents'
]
var metricCategories = [
  'AllMetrics'
]
var logs = [for category in logCategories: {
  category: category
  enabled: true
  retentionPolicy: {
    enabled: true
    days: 0
  }
}]
var metrics = [for category in metricCategories: {
  category: category
  enabled: true
  retentionPolicy: {
    enabled: true
    days: 0
  }
}]

// Resources
resource containerRegistry 'Microsoft.ContainerRegistry/registries@2021-12-01-preview' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: sku
  }
  properties: {
    adminUserEnabled: adminUserEnabled
    publicNetworkAccess: 'Enabled'
  }
}

resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: diagnosticSettingsName
  scope: containerRegistry
  properties: {
    workspaceId: workspaceId
    logs: logs
    metrics: metrics
  }
} 

 resource acrKubeletAcrPullRole_roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: containerRegistry
  name: guid(containerRegistry.id,kubeletidentityObjectId,'b1ff04bb-8a4e-4dc4-8eb5-8693973ce19b')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')  //
    description: 'Allows AKS to pull container images from this ACR instance.'
    principalId: kubeletidentityObjectId //managedClusters_datasynchro_aks_resource.properties.identityProfile.kubeletidentity.objectId
    principalType: 'ServicePrincipal'
  }
 
} 

// Outputs
output id string = containerRegistry.id
output name string = containerRegistry.name
