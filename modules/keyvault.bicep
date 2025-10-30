param keyvault_name string

param workloadManagedIdentityName string

// @secure()
// param secret_name  string
param location string 
resource keyvault 'Microsoft.KeyVault/vaults@2024-12-01-preview' = {
  name: keyvault_name
  location : location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: 'f12a747a-cddf-4426-96ff-ebe055e215a3'
    //accessPolicies: []
    //enabledForDeployment: false
    enableSoftDelete: true
    softDeleteRetentionInDays: 90
    enableRbacAuthorization: true
    enablePurgeProtection: true
   // vaultUri: 'https://${keyvault_name}.vault.azure.net/'
    //provisioningState: 'Succeeded'
    publicNetworkAccess: 'Enabled'
  }
}

resource keyvault_secret 'Microsoft.KeyVault/vaults/secrets@2024-12-01-preview' = {
  parent: keyvault
  name: 'my-secret-ds'
  
  properties: {
    attributes: {
      enabled: true
    }
    value: 'mySecretValue'
  }
}


resource workloadManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: workloadManagedIdentityName
  
}

module KeyVaultSecretsOfficerRole 'roleAssignmentv2.bicep' = {
  name: 'KeyVaultSecretsOfficer'
  params: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b86a8fe4-44ce-4948-aee5-eccb2c155cd7') // Key Vault Secrets Officer
    identityPrincipalId: '7abf4c5b-9638-4ec4-b830-ede0a8031b25' // User Object ID
    roleDescription: 'Perform any action on the secrets of a key vault, except manage permissions'
    principalType:'User'
  }
}


module KeyVaultSecretsUserRole 'roleAssignmentv2.bicep' = {
  name: 'KeyVaultSecretsUser'
  params: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6') // KeyVaultSecretsUser
    identityPrincipalId: workloadManagedIdentity.properties.principalId 
    roleDescription: 'Perform any action on the secrets of a key vault, except manage permissions'
    principalType:'servicePrincipal'
  }
}
