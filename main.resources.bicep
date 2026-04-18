targetScope = 'resourceGroup'
param location string
@minLength(1)
@maxLength(10)
param environmentName string
@minLength(1)
@maxLength(20)
param resourceSuffix string

var acrName ='cr${environmentName}${resourceSuffix}'
var aksName = 'aks-${resourceSuffix}'
var aksNodeResourceGroupName = take('rg-aksnodes-${resourceSuffix}', 80)
var agfcName = 'agfc-${resourceSuffix}'
var albIdentityName = 'id-alb-${resourceSuffix}'
var appIdentityName = 'id-app-${resourceSuffix}'
var kvName = take('kv-${resourceSuffix}', 24)
var lawName = 'law-${resourceSuffix}'
var vnetName = 'vnet-${resourceSuffix}'

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: lawName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: ['10.1.0.0/16']
    }
    subnets: [
      {
        name: 'snet-aks'
        properties: {
          addressPrefix: '10.1.0.0/22'
        }
      }
      {
        name: 'snet-agfc'
        properties: {
          addressPrefix: '10.1.4.0/24'
          delegations: [
            {
              name: 'agfc-delegation'
              properties: {
                serviceName: 'Microsoft.ServiceNetworking/trafficControllers'
              }
            }
          ]
        }
      }
    ]
  }
}

resource agfcSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-09-01' existing = {
  parent: vnet
  name: 'snet-agfc'
}

resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: acrName
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: false
  }
}

resource albIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: albIdentityName
  location: location
}

resource appIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: appIdentityName
  location: location
}

resource aks 'Microsoft.ContainerService/managedClusters@2024-02-01' = {
  name: aksName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    dnsPrefix: 'aks-${resourceSuffix}'
    nodeResourceGroup: aksNodeResourceGroupName
    kubernetesVersion: '1.34'
    agentPoolProfiles: [
      {
        name: 'system'
        count: 2
        vmSize: 'Standard_DS2_v2'
        mode: 'System'
        osType: 'Linux'
        maxPods: 30
        vnetSubnetID: '${vnet.id}/subnets/snet-aks'
        enableAutoScaling: false
      }
    ]
    networkProfile: {
      networkPlugin: 'azure'
      serviceCidr: '10.2.0.0/16'
      dnsServiceIP: '10.2.0.10'
    }
    oidcIssuerProfile: {
      enabled: true
    }
    securityProfile: {
      workloadIdentity: {
        enabled: true
      }
    }
    addonProfiles: {
      omsagent: {
        enabled: true
        config: {
          logAnalyticsWorkspaceResourceID: logAnalytics.id
        }
      }
      azureKeyvaultSecretsProvider: {
        enabled: true
        config: {
          enableSecretRotation: 'true'
          rotationPollInterval: '2m'
        }
      }
    }
  }
}

resource acrPullRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(acr.id, aks.id, 'acrpull')
  scope: acr
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')
    principalId: aks.properties.identityProfile.kubeletidentity.objectId
    principalType: 'ServicePrincipal'
  }
}

resource albFederatedCredential 'Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials@2023-01-31' = {
  parent: albIdentity
  name: 'alb-fic'
  properties: {
    issuer: aks.properties.oidcIssuerProfile.issuerURL
    subject: 'system:serviceaccount:azure-alb-system:alb-controller-sa'
    audiences: [
      'api://AzureADTokenExchange'
    ]
  }
}

resource appFederatedCredential 'Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials@2023-01-31' = {
  parent: appIdentity
  name: 'app-fic'
  properties: {
    issuer: aks.properties.oidcIssuerProfile.issuerURL
    subject: 'system:serviceaccount:datasynchro-app:datasynchro-app-sa'
    audiences: [
      'api://AzureADTokenExchange'
    ]
  }
}

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: kvName
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
    enabledForDeployment: false
    enabledForDiskEncryption: false
    enabledForTemplateDeployment: false
  }
}

resource agfc 'Microsoft.ServiceNetworking/trafficControllers@2023-11-01' = {
  name: agfcName
  location: location
  properties: {}
}

resource agfcFrontend 'Microsoft.ServiceNetworking/trafficControllers/frontends@2023-11-01' = {
  parent: agfc
  name: 'frontend'
  location: location
  properties: {}
}

resource agfcAssociation 'Microsoft.ServiceNetworking/trafficControllers/associations@2023-11-01' = {
  parent: agfc
  name: 'association'
  location: location
  properties: {
    associationType: 'subnets'
    subnet: {
      id: agfcSubnet.id
    }
  }
}

resource albConfigManagerRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, albIdentity.id, 'agfc-config-manager')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'fbc52c3f-28ad-4303-a892-8a056630b8f1')
    principalId: albIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource albNetworkContributorRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(agfcSubnet.id, albIdentity.id, 'network-contributor')
  scope: agfcSubnet
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4d97b98b-1d4f-4787-a291-c67834d212e7')
    principalId: albIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource kvSecretsUserRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, appIdentity.id, 'kv-secrets-user')
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6')
    principalId: appIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

output AZURE_CONTAINER_REGISTRY_ENDPOINT string = acr.properties.loginServer
output AZURE_AKS_CLUSTER_NAME string = aks.name
output AZURE_AGFC_ID string = agfc.id
output AZURE_ALB_IDENTITY_CLIENT_ID string = albIdentity.properties.clientId
output AZURE_APP_IDENTITY_CLIENT_ID string = appIdentity.properties.clientId
output AZURE_KEY_VAULT_NAME string = keyVault.name
output AZURE_TENANT_ID string = subscription().tenantId
