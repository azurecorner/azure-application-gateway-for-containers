param virtualNetworks_datasynchro_vnet_name string = 'datasynchro_vnet'

param userManagedIdentityprincipalId string

@description('Specifies the location.')
param location string 


resource virtualNetworks_datasynchro_vnet_resource 'Microsoft.Network/virtualNetworks@2024-07-01' = {
  name: virtualNetworks_datasynchro_vnet_name
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.11.0.0/16'
      ]
    }
    privateEndpointVNetPolicies: 'Disabled'
    subnets: [
      {
        name: 'subnet-alb'
        properties: {
          addressPrefix: '10.11.1.0/24'
          delegations: [
            {
              name: 'delegationToMicrosoftAppGatewayForContainers'
              properties: {
                serviceName: 'Microsoft.ServiceNetworking/trafficControllers'
              }
            }
          ]
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
        type: 'Microsoft.Network/virtualNetworks/subnets'
      }

      {
        name: 'subnet-aks'
        properties: {
          addressPrefix: '10.11.2.0/24'
         
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
        type: 'Microsoft.Network/virtualNetworks/subnets'
      }
    ]
   
    enableDdosProtection: false
  }
}

resource subnetAlb 'Microsoft.Network/virtualNetworks/subnets@2024-07-01' existing = {
  parent: virtualNetworks_datasynchro_vnet_resource
  name: 'subnet-alb'
}

resource subnetAks 'Microsoft.Network/virtualNetworks/subnets@2024-07-01' existing = {
  parent: virtualNetworks_datasynchro_vnet_resource
  name: 'subnet-aks'
}
 //Assignation du rôle Network Contributor sur le sous-réseau ALB
 resource subnetAlbNetworkContributorAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subnetAlb.id, userManagedIdentityprincipalId, '4d97b98b-1d4f-4787-a291-c67834d212e7')
  scope: subnetAlb
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4d97b98b-1d4f-4787-a291-c67834d212e7') // Network Contributor
    principalId: userManagedIdentityprincipalId
    principalType: 'ServicePrincipal'
    description: 'Grant Network Contributor role on subnet-alb to the ALB managed identity'
  }
}
 
output id string = virtualNetworks_datasynchro_vnet_resource.id

output alb_subnet_id string = subnetAlb.id


output aks_subnet_id string = subnetAks.id



