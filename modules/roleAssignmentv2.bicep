
@description('Role definition resource id or well-known built-in role id. Example: /subscriptions/<sub>/providers/Microsoft.Authorization/roleDefinitions/<roleGuid>')
param roleDefinitionId string

@description('The principal id (objectId) of the identity to assign the role to (service principal or managed identity).')
param identityPrincipalId string

@description('Description of role assignment')
param roleDescription string 

@description('The principal type of the assigned principal ID.')
param principalType string

// Create deterministic name for the role assignment
var roleAssignmentName = guid(resourceGroup().id, roleDefinitionId, identityPrincipalId)

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: roleAssignmentName
  properties: {
    roleDefinitionId: roleDefinitionId
    principalId: identityPrincipalId
    principalType: principalType
    description: roleDescription
  }
}
