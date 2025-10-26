
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


 
output issuerUrl string = managedClusters_datasynchro_aks_resource.properties.oidcIssuerProfile.issuerURL

output kubeletidentityObjectId string = managedClusters_datasynchro_aks_resource.properties.identityProfile.kubeletidentity.objectId
