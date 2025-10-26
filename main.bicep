param virtualNetworks_datasynchro_vnet_name string = 'datasynchro_vnet'
param trafficControllers_alb_name string = 'datasynchro_alb'
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

@description('Specifies the name of the container registry.')
param tags object 


resource userAssignedIdentities_azure_alb_identity_resource 'Microsoft.ManagedIdentity/userAssignedIdentities@2025-01-31-preview' = {
  name: userAssignedIdentities_azure_alb_identity_name
  location: 'eastus'
}

resource virtualNetworks_datasynchro_vnet_resource 'Microsoft.Network/virtualNetworks@2024-07-01' = {
  name: virtualNetworks_datasynchro_vnet_name
  location: 'eastus'
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

resource trafficControllers_alb_resource 'Microsoft.ServiceNetworking/trafficControllers@2025-03-01-preview' = {
  name: trafficControllers_alb_name
  location: 'eastus'
  properties: {}
}


 resource userAssignedIdentities_azure_alb_identity_name_userAssignedIdentities_azure_alb_identity_name 'Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials@2025-01-31-preview' = {
  parent: userAssignedIdentities_azure_alb_identity_resource
  name: userAssignedIdentities_azure_alb_identity_name
  properties: {
    issuer: managedClusters_datasynchro_aks_resource.properties.oidcIssuerProfile.issuerURL
    subject: 'system:serviceaccount:azure-alb-system:alb-controller-sa' // 'system:serviceaccount:${namespace}:${serviceAccountName}'
    audiences: [
      'api://AzureADTokenExchange'
    ]
  }
} 


resource trafficControllers_alb_test_name_association 'Microsoft.ServiceNetworking/trafficControllers/associations@2025-03-01-preview' = {
  parent: trafficControllers_alb_resource
  name: 'datasynchro-association'
  location: 'eastus'
  properties: {
    associationType: 'subnets'
    subnet: {
      id: '${virtualNetworks_datasynchro_vnet_resource.id}/subnets/subnet-alb'
    }
  }
}

resource trafficControllers_alb_test_name_frontend 'Microsoft.ServiceNetworking/trafficControllers/frontends@2025-03-01-preview' = {
  parent: trafficControllers_alb_resource
  name: 'datasynchro-frontend'
  location: 'eastus'
  properties: {}
}

var nodeResourceGroupName = 'MC_RG-APPLICATION-GATEWAY-FOR-CONTAINER_${managedClusters_datasynchro_aks_name}_eastus'

resource managedClusters_datasynchro_aks_resource 'Microsoft.ContainerService/managedClusters@2025-05-01' = {
  name: managedClusters_datasynchro_aks_name
  location: 'eastus'
  sku: {
    name: 'Base'
    tier: 'Free'
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    kubernetesVersion: '1.32.7'
    dnsPrefix: 'datasynchr-RG-APPLICATION-G-023b20'
    agentPoolProfiles: [
      {
       name: 'agentpool'
        osDiskSizeGB: 128
        count: 1
        enableAutoScaling: true
        minCount: 1
        maxCount: 2
        vmSize: 'Standard_DS2_v2'
        osType: 'Linux'
        osSKU: 'Ubuntu'
        type: 'VirtualMachineScaleSets'
        mode: 'System'
        maxPods: 110
        enableNodePublicIP: false
        vnetSubnetID: '${virtualNetworks_datasynchro_vnet_resource.id}/subnets/subnet-aks'
      }      
    ]
  
    nodeResourceGroup: nodeResourceGroupName
    enableRBAC: true
    supportPlan: 'KubernetesOfficial'
    networkProfile: {
      loadBalancerSku: 'standard'
      networkPlugin: 'azure'
      networkPluginMode: 'overlay'
      networkDataplane: 'azure'
      networkPolicy: 'azure'
    }


    aadProfile: {
      adminGroupObjectIDs: adminGroupObjectIDs
      enableAzureRBAC: true
      managed: true
      tenantID: tenant().tenantId
    }
    securityProfile: {
      workloadIdentity: {
        enabled: true
      }
    }
    
    oidcIssuerProfile: {
      enabled: true
    }
  }
}


module AppGwForContainersConfigurationManagerRole_roleAssignment 'modules/roleAssignment.bicep' = {
  
  name: 'applyReaderRoleToAksRG'
  scope: resourceGroup()
  params: {

    identityPrincipalId: userAssignedIdentities_azure_alb_identity_resource.properties.principalId
    roleDefinitionId:'fbc52c3f-28ad-4303-a892-8a056630b8f1'
     description: 'Apply Reader role to the AKS managed cluster resource group for the newly provisioned identity'
     principalType: 'ServicePrincipal'
  }
}
 
module readerRole 'modules/roleAssignment.bicep' = {
  name: 'applyReaderRoleToAksRG'
  scope: resourceGroup(nodeResourceGroupName)
  params: {
    identityPrincipalId: userAssignedIdentities_azure_alb_identity_resource.properties.principalId
    roleDefinitionId: 'acdd72a7-3385-48ef-bd42-f606fba81ae7' // Reader
    description:  'Apply Reader role to the AKS managed cluster resource group for the newly provisioned identity'
    principalType: 'ServicePrincipal'
  }
  dependsOn:[
    managedClusters_datasynchro_aks_resource
  ]
}
 
//  Référence au sous-réseau ALB
resource subnetAlb 'Microsoft.Network/virtualNetworks/subnets@2024-07-01' existing = {
  parent: virtualNetworks_datasynchro_vnet_resource
  name: 'subnet-alb'
}

//  Assignation du rôle Network Contributor sur le sous-réseau ALB
resource subnetAlbNetworkContributorAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subnetAlb.id, userAssignedIdentities_azure_alb_identity_resource.id, 'Network Contributor'/*'4d97b98b-1d4f-4787-a291-c67834d212e7'*/)
  scope: subnetAlb
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4d97b98b-1d4f-4787-a291-c67834d212e7') // Network Contributor
    principalId: userAssignedIdentities_azure_alb_identity_resource.properties.principalId
    principalType: 'ServicePrincipal'
    description: 'Grant Network Contributor role on subnet-alb to the ALB managed identity'
  }
}


resource kubernetesServiceClusterAdminRole_roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: managedClusters_datasynchro_aks_resource
  name: guid(managedClusters_datasynchro_aks_resource.id,adminGroupObjectIDs[0],'b1ff04bb-8a4e-4dc4-8eb5-8693973ce19b')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b1ff04bb-8a4e-4dc4-8eb5-8693973ce19b') 
    description: 'Azure Kubernetes Service RBAC Cluster Admin Role to manage all resources in the cluster.'
    principalId: adminGroupObjectIDs[0]
    principalType: 'User'
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
    tags: tags
  }
}

resource containerRegistryResource 'Microsoft.ContainerRegistry/registries@2025-04-01' existing = {
  name: containerRegistryName
  dependsOn: [
    containerRegistry
  ]
}

resource acrKubeletAcrPullRole_roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: containerRegistryResource
  name: guid(containerRegistryResource.id,managedClusters_datasynchro_aks_resource.id,'b1ff04bb-8a4e-4dc4-8eb5-8693973ce19b')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')  //
    description: 'Allows AKS to pull container images from this ACR instance.'
    principalId: managedClusters_datasynchro_aks_resource.properties.identityProfile.kubeletidentity.objectId
    principalType: 'ServicePrincipal'
  }
  dependsOn: [
    containerRegistry
  ]
} 
