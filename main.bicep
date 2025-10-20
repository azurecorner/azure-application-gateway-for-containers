param virtualNetworks_datasynchro_vnet_name string = 'datasynchro-vnet'
param trafficControllers_alb_test_name string = 'alb-test'
param managedClusters_datasynchro_aks_name string = 'datasynchro-aks'
param userAssignedIdentities_azure_alb_identity_name string = 'azure-alb-identity'
param userAssignedIdentities_datasynchro_aks_agentpool_externalid string = '/subscriptions/023b2039-5c23-44b8-844e-c002f8ed431d/resourceGroups/MC_RG-APPLICATION-GATEWAY-FOR-CONTAINER_datasynchro-aks_eastus/providers/Microsoft.ManagedIdentity/userAssignedIdentities/datasynchro-aks-agentpool'
param virtualNetworks_aks_vnet_20795260_externalid string = '/subscriptions/023b2039-5c23-44b8-844e-c002f8ed431d/resourceGroups/MC_RG-APPLICATION-GATEWAY-FOR-CONTAINER_datasynchro-aks_eastus/providers/Microsoft.Network/virtualNetworks/aks-vnet-20795260'

resource managedClusters_datasynchro_aks_name_resource 'Microsoft.ContainerService/managedClusters@2025-05-01' = {
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
      }
    ]
    linuxProfile: {
      adminUsername: 'azureuser'
      ssh: {
        publicKeys: [
          {
            keyData: 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCRv1lwCZomhx+Jp7Lb/67o/bUDGdtJzniGRJ5uG6UmSU5UNRZohQ5D7hOX3OpcdfvbiRlEND+kYCsegljpINz1KUU19wcIskrYtfY4e9clOoBvv1WkS3gp3UV2moLN8N1/TMy53P995nbCyso8ZCMXqqZW5xDeD1EPFHxdP5YbWdL9IX7sqfL1UcEgisHLDGklDCROWrvAKg0JfZxTnWA9ZTWqshAUkuDdU12sFIc4tFBgjc2yCDalTz0NndrWBf8U7M3kPEpBEgceYTHE8n80iQ7cBRLaeciuagFNT9rZ0Z7MW1hejiJMzYY/u/JUgMzXMK31laEukW+G4m8UdI3H'
          }
        ]
      }
    }
    windowsProfile: {
      adminUsername: 'azureuser'
      enableCSIProxy: true
    }
    servicePrincipalProfile: {
      clientId: 'msi'
    }
    addonProfiles: {
      azurepolicy: {
        enabled: true
      }
    }
    nodeResourceGroup: 'MC_RG-APPLICATION-GATEWAY-FOR-CONTAINER_${managedClusters_datasynchro_aks_name}_eastus'
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
      serviceCidr: '10.0.0.0/16'
      dnsServiceIP: '10.0.0.10'
      outboundType: 'loadBalancer'
      serviceCidrs: [
        '10.0.0.0/16'
      ]
      ipFamilies: [
        'IPv4'
      ]
    }
    identityProfile: {
      kubeletidentity: {
        resourceId: userAssignedIdentities_datasynchro_aks_agentpool_externalid
        clientId: '3710d5a7-8303-4783-ba8f-166bfe392c7a'
        objectId: '7dfe6898-d75e-4854-8e91-8791db08d93e'
      }
    }
    autoUpgradeProfile: {
      nodeOSUpgradeChannel: 'NodeImage'
    }
    disableLocalAccounts: false
    securityProfile: {
      workloadIdentity: {
        enabled: true
      }
    }
    storageProfile: {
      diskCSIDriver: {
        enabled: true
      }
      fileCSIDriver: {
        enabled: true
      }
      snapshotController: {
        enabled: true
      }
    }
    oidcIssuerProfile: {
      enabled: true
    }
    workloadAutoScalerProfile: {}
    metricsProfile: {
      costAnalysis: {
        enabled: false
      }
    }
    nodeProvisioningProfile: {
      mode: 'Manual'
      defaultNodePools: 'Auto'
    }
    bootstrapProfile: {
      artifactSource: 'Direct'
    }
  }
}

resource userAssignedIdentities_azure_alb_identity_name_resource 'Microsoft.ManagedIdentity/userAssignedIdentities@2025-01-31-preview' = {
  name: userAssignedIdentities_azure_alb_identity_name
  location: 'eastus'
}

resource virtualNetworks_datasynchro_vnet_name_resource 'Microsoft.Network/virtualNetworks@2024-07-01' = {
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
        id: virtualNetworks_datasynchro_vnet_name_subnet_alb.id
        properties: {
          addressPrefix: '10.11.1.0/24'
          delegations: []
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
        type: 'Microsoft.Network/virtualNetworks/subnets'
      }
    ]
    virtualNetworkPeerings: [
      {
        name: 'P2'
        id: virtualNetworks_datasynchro_vnet_name_P2.id
        properties: {
          peeringState: 'Connected'
          peeringSyncLevel: 'FullyInSync'
          remoteVirtualNetwork: {
            id: virtualNetworks_aks_vnet_20795260_externalid
          }
          allowVirtualNetworkAccess: true
          allowForwardedTraffic: true
          allowGatewayTransit: false
          useRemoteGateways: false
          doNotVerifyRemoteGateways: false
          peerCompleteVnets: true
          remoteAddressSpace: {
            addressPrefixes: [
              '10.224.0.0/12'
            ]
          }
          remoteVirtualNetworkAddressSpace: {
            addressPrefixes: [
              '10.224.0.0/12'
            ]
          }
        }
        type: 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings'
      }
    ]
    enableDdosProtection: false
  }
}

resource trafficControllers_alb_test_name_resource 'Microsoft.ServiceNetworking/trafficControllers@2025-03-01-preview' = {
  name: trafficControllers_alb_test_name
  location: 'eastus'
  properties: {}
}

resource managedClusters_datasynchro_aks_name_nodepool1 'Microsoft.ContainerService/managedClusters/agentPools@2025-05-01' = {
  parent: managedClusters_datasynchro_aks_name_resource
  name: 'nodepool1'
  properties: {
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
  }
}

resource userAssignedIdentities_azure_alb_identity_name_userAssignedIdentities_azure_alb_identity_name 'Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials@2025-01-31-preview' = {
  parent: userAssignedIdentities_azure_alb_identity_name_resource
  name: '${userAssignedIdentities_azure_alb_identity_name}'
  properties: {
    issuer: 'https://eastus.oic.prod-aks.azure.com/f12a747a-cddf-4426-96ff-ebe055e215a3/c0bef122-9624-46ed-b835-79e0180aa240/'
    subject: 'system:serviceaccount:azure-alb-system:alb-controller-sa'
    audiences: [
      'api://AzureADTokenExchange'
    ]
  }
}

resource virtualNetworks_datasynchro_vnet_name_subnet_alb 'Microsoft.Network/virtualNetworks/subnets@2024-07-01' = {
  name: '${virtualNetworks_datasynchro_vnet_name}/subnet-alb'
  properties: {
    addressPrefix: '10.11.1.0/24'
    delegations: []
    privateEndpointNetworkPolicies: 'Disabled'
    privateLinkServiceNetworkPolicies: 'Enabled'
  }
  dependsOn: [
    virtualNetworks_datasynchro_vnet_name_resource
  ]
}

resource virtualNetworks_datasynchro_vnet_name_P2 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2024-07-01' = {
  name: '${virtualNetworks_datasynchro_vnet_name}/P2'
  properties: {
    peeringState: 'Connected'
    peeringSyncLevel: 'FullyInSync'
    remoteVirtualNetwork: {
      id: virtualNetworks_aks_vnet_20795260_externalid
    }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: false
    doNotVerifyRemoteGateways: false
    peerCompleteVnets: true
    remoteAddressSpace: {
      addressPrefixes: [
        '10.224.0.0/12'
      ]
    }
    remoteVirtualNetworkAddressSpace: {
      addressPrefixes: [
        '10.224.0.0/12'
      ]
    }
  }
  dependsOn: [
    virtualNetworks_datasynchro_vnet_name_resource
  ]
}

resource trafficControllers_alb_test_name_association_test 'Microsoft.ServiceNetworking/trafficControllers/associations@2025-03-01-preview' = {
  parent: trafficControllers_alb_test_name_resource
  name: 'association-test'
  location: 'eastus'
  properties: {
    associationType: 'subnets'
    subnet: {
      id: '${virtualNetworks_aks_vnet_20795260_externalid}/subnets/subnet-alb'
    }
  }
}

resource trafficControllers_alb_test_name_test_frontend 'Microsoft.ServiceNetworking/trafficControllers/frontends@2025-03-01-preview' = {
  parent: trafficControllers_alb_test_name_resource
  name: 'test-frontend'
  location: 'eastus'
  properties: {}
}

resource managedClusters_datasynchro_aks_name_nodepool1_aks_nodepool1_21103474_vmss000000 'Microsoft.ContainerService/managedClusters/agentPools/machines@2025-04-02-preview' = {
  parent: managedClusters_datasynchro_aks_name_nodepool1
  name: 'aks-nodepool1-21103474-vmss000000'
  properties: {
    network: {}
  }
  dependsOn: [
    managedClusters_datasynchro_aks_name_resource
  ]
}

resource managedClusters_datasynchro_aks_name_nodepool1_aks_nodepool1_21103474_vmss000001 'Microsoft.ContainerService/managedClusters/agentPools/machines@2025-04-02-preview' = {
  parent: managedClusters_datasynchro_aks_name_nodepool1
  name: 'aks-nodepool1-21103474-vmss000001'
  properties: {
    network: {}
  }
  dependsOn: [
    managedClusters_datasynchro_aks_name_resource
  ]
}

resource managedClusters_datasynchro_aks_name_nodepool1_aks_nodepool1_21103474_vmss000002 'Microsoft.ContainerService/managedClusters/agentPools/machines@2025-04-02-preview' = {
  parent: managedClusters_datasynchro_aks_name_nodepool1
  name: 'aks-nodepool1-21103474-vmss000002'
  properties: {
    network: {}
  }
  dependsOn: [
    managedClusters_datasynchro_aks_name_resource
  ]
}
