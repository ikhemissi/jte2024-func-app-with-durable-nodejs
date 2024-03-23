metadata description = 'Creates a role assignment under the specified namespace.'
param namespace string
param roleDefinitionId string
param principalId string = ''

resource role 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(servicebus.id, roleDefinitionId, principalId)
  scope: servicebus
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionId)
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}

resource servicebus 'Microsoft.ServiceBus/namespaces@2022-01-01-preview' existing = {
  name: namespace
}
