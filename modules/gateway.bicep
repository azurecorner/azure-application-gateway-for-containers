
param trafficControllers_alb_name string
param alb_subnet_id string

param userManagedIdentityprincipalId string

param nodeResourceGroupName string

@description('Specifies the location.')
param location string 

resource trafficControllers_alb_resource 'Microsoft.ServiceNetworking/trafficControllers@2025-03-01-preview' = {
  name: trafficControllers_alb_name
  location: location
  properties: {}
}

resource trafficControllers_alb_test_name_association 'Microsoft.ServiceNetworking/trafficControllers/associations@2025-03-01-preview' = {
  parent: trafficControllers_alb_resource
  name: 'datasynchro-association'
  location: location
  properties: {
    associationType: 'subnets'
    subnet: {
      id: alb_subnet_id
    }
  }
}

resource trafficControllers_alb_test_name_frontend 'Microsoft.ServiceNetworking/trafficControllers/frontends@2025-03-01-preview' = {
  parent: trafficControllers_alb_resource
  name: 'datasynchro-frontend'
  location: location
  properties: {}
}


module AppGwForContainersConfigurationManagerRole_roleAssignment 'roleAssignment.bicep' = {
  
  name: 'applyReaderRoleToAksRG'
  scope: resourceGroup()
  params: {

    identityPrincipalId: userManagedIdentityprincipalId
    roleDefinitionId:'fbc52c3f-28ad-4303-a892-8a056630b8f1'
     description: 'Apply Reader role to the AKS managed cluster resource group for the newly provisioned identity'
     principalType: 'ServicePrincipal'
  }
}

module readerRole 'roleAssignment.bicep' = {
  name: 'applyReaderRoleToAksManagedRG'
  scope: resourceGroup(nodeResourceGroupName)
  params: {
    identityPrincipalId: userManagedIdentityprincipalId
    roleDefinitionId: 'acdd72a7-3385-48ef-bd42-f606fba81ae7' // Reader
    description:  'Apply Reader role to the AKS managed cluster resource group for the newly provisioned identity'
    principalType: 'ServicePrincipal'
  }
 
}



 