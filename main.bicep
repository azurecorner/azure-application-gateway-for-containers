param virtualNetworks_datasynchro_vnet_name string = 'datasynchro_vnet'
param managedClusters_datasynchro_aks_name string = 'datasynchro-aks'
param userAssignedIdentities_azure_alb_identity_name string = 'azure_alb_identity'
@description('The list of AAD group object IDs that will have admin role of the cluster.')
param adminGroupObjectIDs array =['7abf4c5b-9638-4ec4-b830-ede0a8031b25']
@description('Name of your Azure Container Registry')
param  containerRegistryName string
@description('Tier of your Azure Container Registry.')
param  containerRegistrySku string

param location string = resourceGroup().location

param logAnalyticsWorkspaceName string

param nodeResourceGroupName string= 'MC_RG-APPLICATION-GATEWAY-FOR-CONTAINER_${managedClusters_datasynchro_aks_name}_eastus'

param serviceAccountName string = 'alb-controller-sa'

param controllerNamespace string ='azure-alb-system'

param trafficControllers_alb_name string = 'datasynchro_alb'

@description('Specifies the name of the container registry.')
param tags object 


resource userAssignedIdentities_azure_alb_identity_resource 'Microsoft.ManagedIdentity/userAssignedIdentities@2025-01-31-preview' = {
  name: userAssignedIdentities_azure_alb_identity_name
  location: location
}


module virtual_network 'modules/virtual_network.bicep' = {
name:'virtual_network'
 params: {
  virtualNetworks_datasynchro_vnet_name: virtualNetworks_datasynchro_vnet_name
  location: location
  userManagedIdentityprincipalId : userAssignedIdentities_azure_alb_identity_resource.properties.principalId
}

}


resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2021-12-01-preview' = {
  name: logAnalyticsWorkspaceName
  tags: tags
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
  }
}

module containerRegistry 'modules/containerRegistry.bicep' = {
  name: 'containerRegistry'
  params: {
    name: containerRegistryName
    sku: containerRegistrySku
    adminUserEnabled : false
    location: location
     workspaceId: logAnalyticsWorkspace.id
     kubeletidentityObjectId: kubernetes.outputs.kubeletidentityObjectId
    tags: tags
  }
}


module kubernetes 'modules/kubernetes.bicep' = {
  name:'kubernetes'
  params: {
    location: location
    adminGroupObjectIDs: adminGroupObjectIDs
    aks_subnet_id: virtual_network.outputs.aks_subnet_id
    
      managedClusters_datasynchro_aks_name: managedClusters_datasynchro_aks_name
  nodeResourceGroupName: nodeResourceGroupName
  }
}

module gateway 'modules/gateway.bicep' = {
  name:'gateway'
  params: {
    
    trafficControllers_alb_name: trafficControllers_alb_name
    location: location
    alb_subnet_id:virtual_network.outputs.alb_subnet_id
     nodeResourceGroupName: nodeResourceGroupName
     userManagedIdentityprincipalId: userAssignedIdentities_azure_alb_identity_resource.properties.principalId
  
  }
  dependsOn: [
    kubernetes
  ]
}
 
resource userAssignedIdentities_azure_alb_identity_name_userAssignedIdentities_azure_alb_identity_name 'Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials@2025-01-31-preview' = {
  parent: userAssignedIdentities_azure_alb_identity_resource
  name: userAssignedIdentities_azure_alb_identity_name
  properties: {
    issuer: kubernetes.outputs.issuerUrl // managedClusters_datasynchro_aks_resource.properties.oidcIssuerProfile.issuerURL
    subject: 'system:serviceaccount:${controllerNamespace}:${serviceAccountName}' //'system:serviceaccount:azure-alb-system:alb-controller-sa' // 
    audiences: [
      'api://AzureADTokenExchange'
    ]
  }
} 


output sunet_aks_id string= virtual_network.outputs.aks_subnet_id

output alb_subnet_id string= virtual_network.outputs.alb_subnet_id
