param identityPrincipalId string
param roleDefinitionId string 
param description string 
//@allowed('user','ServicePrincipal')
param principalType string

resource ReaderRole_roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, identityPrincipalId, roleDefinitionId)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionId)
    description: description
    principalId: identityPrincipalId
    principalType: principalType
  }
}
 

