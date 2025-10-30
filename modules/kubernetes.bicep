
param managedClusters_datasynchro_aks_name string = 'datasynchro-aks'
param aks_subnet_id string
param adminGroupObjectIDs string[]

param nodeResourceGroupName string

@description('Specifies the location.')
param location string 


resource managedClusters_datasynchro_aks_resource 'Microsoft.ContainerService/managedClusters@2025-05-01' = {
  name: managedClusters_datasynchro_aks_name
  location: location
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
        vnetSubnetID: aks_subnet_id
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

// azure ai
param workloadManagedIdentityName string
param tags object = {}
param serviceAccountName string = 'workload-identity-sa'

param serviceAccountNameNamespace string ='azure-resources'



//  This user-defined managed identity used by the workload to connect to the Azure OpenAI resource with a security token issued by Azue Active Directory
resource workloadManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: workloadManagedIdentityName
  location: location
  tags: tags
}

// resource cognitiveServicesUserRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
//   name: 'a97b65f3-24c7-4388-baec-2e87135dc908'
//   scope: subscription()
// }

// // Assign the Cognitive Services User role to the user-defined managed identity used by workloads
// resource cognitiveServicesUserRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
//   name:  guid(workloadManagedIdentity.id, cognitiveServicesUserRole.id)
//   scope: resourceGroup()
//   properties: {
//     roleDefinitionId: cognitiveServicesUserRole.id
//     principalId: workloadManagedIdentity.properties.principalId
//     principalType: 'ServicePrincipal'
//   }
// }

module AppGwForContainersConfigurationManagerRole_roleAssignment 'roleAssignment.bicep' = {
  
  name: 'applycognitiveServicesUserRoleToOpenAiRG'
  scope: resourceGroup()
  params: {

    identityPrincipalId: workloadManagedIdentity.properties.principalId
    roleDefinitionId:'a97b65f3-24c7-4388-baec-2e87135dc908'
     description: 'Assign the Cognitive Services User role to the user-defined managed identity used by workloads'
     principalType: 'ServicePrincipal'
  }
}


module AzureAiUserRole 'roleAssignmentv2.bicep' = {
  name: 'AzureAiUserRole'
  params: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '53ca6127-db72-4b80-b1b0-d745d6d5456d') //Azure AI User
    identityPrincipalId: workloadManagedIdentity.properties.principalId // system assigned managed identity of the vm running the workload
    roleDescription: 'Grants reader access to AI projects, reader access to AI accounts, and data actions for an AI project.'
    principalType:'ServicePrincipal'
  }
}


// Create federated identity for the user-defined managed identity used by the workload
resource federatedIdentityCredentials 'Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials@2023-01-31' =  {
  name: 'WorkloadFederatedIdentityCredentials'
  parent: workloadManagedIdentity
  properties: {
    issuer: managedClusters_datasynchro_aks_resource.properties.oidcIssuerProfile.issuerURL
    subject: 'system:serviceaccount:${serviceAccountNameNamespace}:${serviceAccountName}'
    audiences: [
      'api://AzureADTokenExchange'
    ]
  }
}


 
output issuerUrl string = managedClusters_datasynchro_aks_resource.properties.oidcIssuerProfile.issuerURL

output kubeletidentityObjectId string = managedClusters_datasynchro_aks_resource.properties.identityProfile.kubeletidentity.objectId
