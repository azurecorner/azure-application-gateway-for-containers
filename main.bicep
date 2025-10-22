param virtualNetworks_datasynchro_vnet_name string = 'datasynchro_vnet'
param trafficControllers_alb_name string = 'datasynchro_alb'
param managedClusters_datasynchro_aks_name string = 'datasynchro-aks'
param userAssignedIdentities_azure_alb_identity_name string = 'azure_alb_identity'

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
        name: 'nodepool1'
        count: 3
        vmSize: 'Standard_DS2_v2'
        osDiskSizeGB: 128
        osDiskType: 'Managed'
        kubeletDiskType: 'OS'
        maxPods: 30
        type: 'VirtualMachineScaleSets'
        enableAutoScaling: false
        scaleDownMode: 'Delete'
        powerState: {
          code: 'Running'
        }
        orchestratorVersion: '1.32.7'
        enableNodePublicIP: false
        mode: 'System'
        enableEncryptionAtHost: false
        enableUltraSSD: false
        osType: 'Linux'
        osSKU: 'Ubuntu'
        upgradeSettings: {
          maxSurge: '10%'
          maxUnavailable: '0'
        }
        enableFIPS: false
        securityProfile: {
          enableVTPM: false
          enableSecureBoot: false
        }
        vnetSubnetID: '${virtualNetworks_datasynchro_vnet_resource.id}/subnets/subnet-aks'
      }
      
    ]
  
    nodeResourceGroup: nodeResourceGroupName
    enableRBAC: true
    supportPlan: 'KubernetesOfficial'
    networkProfile: {
      networkPlugin: 'azure'
      networkPolicy: 'none'
      networkDataplane: 'azure'
      loadBalancerSku: 'standard'
      loadBalancerProfile: {
        managedOutboundIPs: {
          count: 1
        }
        backendPoolType: 'nodeIPConfiguration'
      }
     
    }

    disableLocalAccounts: false
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

// Delegate AppGw for Containers Configuration Manager role to RG containing Application Gateway for Containers resource
resource AppGwForContainersConfigurationManagerRole_roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: resourceGroup()
  name: guid(resourceGroup().id,userAssignedIdentities_azure_alb_identity_resource.id,'fbc52c3f-28ad-4303-a892-8a056630b8f1') //AppGw for Containers Configuration Manager
  
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'fbc52c3f-28ad-4303-a892-8a056630b8f1') //'fbc52c3f-28ad-4303-a892-8a056630b8f1' // Reader role
    description: 'Apply Reader role to the AKS managed cluster resource group for the newly provisioned identity'
    principalId: userAssignedIdentities_azure_alb_identity_resource.properties.principalId
    principalType: 'ServicePrincipal'
    
  }
}
 
module readerRole 'roleAssignment.bicep' = {
  name: 'applyReaderRoleToAksRG'
  scope: resourceGroup(nodeResourceGroupName)
  params: {
    identityPrincipalId: userAssignedIdentities_azure_alb_identity_resource.properties.principalId
    roleDefinitionId: 'acdd72a7-3385-48ef-bd42-f606fba81ae7' // Reader
    description:  'Apply Reader role to the AKS managed cluster resource group for the newly provisioned identity'
    principalType: 'ServicePrincipal'
  }
}
 
//  Référence au sous-réseau ALB
resource subnetAlb 'Microsoft.Network/virtualNetworks/subnets@2024-07-01' existing = {
  parent: virtualNetworks_datasynchro_vnet_resource
  name: 'subnet-alb'
}

//  Assignation du rôle Network Contributor sur le sous-réseau ALB
resource subnetAlbNetworkContributorAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subnetAlb.id, userAssignedIdentities_azure_alb_identity_resource.id, '4d97b98b-1d4f-4787-a291-c67834d212e7')
  scope: subnetAlb
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4d97b98b-1d4f-4787-a291-c67834d212e7') // Network Contributor
    principalId: userAssignedIdentities_azure_alb_identity_resource.properties.principalId
    principalType: 'ServicePrincipal'
    description: 'Grant Network Contributor role on subnet-alb to the ALB managed identity'
  }
}


