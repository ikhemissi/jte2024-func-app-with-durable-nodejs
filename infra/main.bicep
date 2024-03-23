targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name which is used to generate a short unique hash for each resource')
param name string

@minLength(1)
@description('Primary location for all resources')
param location string

var resourceToken = toLower(uniqueString(subscription().id, name, location))
var tags = { 'azd-env-name': name }

var prefix = '${name}-${resourceToken}'

resource resourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: '${name}-rg'
  location: location
  tags: tags
}

module storageAccount './storageaccount.bicep' = {
  name: 'storageAccount'
  scope: resourceGroup
  params: {
    name: '${toLower(take(replace(prefix, '-', ''), 17))}storage'
    location: location
    tags: tags
  }
}

module orderValidationFunctionApp './functionapp.bicep' = {
  name: 'order-validation-func'
  scope: resourceGroup
  params: {
    name: '${prefix}-validation-func'
    hostingPlanName: '${prefix}-plan'
    location: location
    runtimeName: 'node'
    runtimeVersion: '20'
    azdServiceName: 'validation'
    storageAccountName: storageAccount.outputs.storageAccountName
    appInsightsInstrumentationKey: applicationInsights.outputs.instrumentationKey
    tags: tags
    environmentVariables: [
      {
        name: 'SB_ORDERS__fullyQualifiedNamespace'
        value: servicebus.outputs.fullyQualifiedNamespace
      }
      {
        name: 'SERVICEBUS_QUEUE'
        value: 'orders'
      }
    ]
  }
}

module orderProcessingFunctionApp './functionapp.bicep' = {
  name: 'order-processing-func'
  scope: resourceGroup
  params: {
    name: '${prefix}-processing-func'
    hostingPlanName: '${prefix}-plan'
    location: location
    runtimeName: 'node'
    runtimeVersion: '20'
    azdServiceName: 'processing'
    storageAccountName: storageAccount.outputs.storageAccountName
    appInsightsInstrumentationKey: applicationInsights.outputs.instrumentationKey
    tags: tags
    environmentVariables: [
      {
        name: 'SB_ORDERS__fullyQualifiedNamespace'
        value: servicebus.outputs.fullyQualifiedNamespace
      }
      {
        name: 'SERVICEBUS_QUEUE'
        value: 'orders'
      }
      {
        name: 'COSMOS_ORDERS__accountEndpoint'
        value: cosmos.outputs.endpoint
      }
      {
        name: 'COSMOSDB_DATABASE'
        value: 'orders'
      }
      {
        name: 'COSMOSDB_CONTAINER'
        value: 'orders'
      }
    ]
  }
}

module applicationInsights './appinsights.bicep' = {
  scope: resourceGroup
  name: 'appinsights'
  params: {
    name: '${prefix}-insights'
    location: location
    tags: tags
  }
}

module cosmos './cosmos.bicep' = {
  scope: resourceGroup
  name: 'cosmos'
  params: {
    accountName: '${prefix}-cosmos'
    databaseName: 'orders'
    location: location
    tags: tags
    // keyVaultName: keyVault.outputs.name
  }
}

module servicebus './servicebus.bicep' = {
  scope: resourceGroup
  name: 'servicebus'
  params: {
    serviceBusNamespaceName: '${prefix}-servicebus'
    serviceBusQueueName: 'orders'
    location: location
    tags: tags
  }
}

module cosmosContributorAssignment './core/database/cosmos/sql/cosmos-sql-role-assign.bicep' = {
  scope: resourceGroup
  name: 'cosmosContributorAssignment'
  params: {
    accountName: cosmos.outputs.accountName
    roleDefinitionId: cosmos.outputs.roleDefinitionId
    principalId: orderProcessingFunctionApp.outputs.principalId
  }
}

module servicebusDataSenderAssignment './servicebus-role-assign.bicep' = {
  scope: resourceGroup
  name: 'servicebusDataSenderAssignment'
  params: {
    namespace: servicebus.outputs.namespaceName
    roleDefinitionId: '69a216fc-b8fb-44d8-bc22-1f3c2cd27a39' // Azure Service Bus Data Sender
    principalId: orderValidationFunctionApp.outputs.principalId
  }
}

module servicebusDataReceiverAssignment './servicebus-role-assign.bicep' = {
  scope: resourceGroup
  name: 'servicebusDataReceiverAssignment'
  params: {
    namespace: servicebus.outputs.namespaceName
    roleDefinitionId: '4f6d3b9b-027b-4f4c-9142-0e5a2a2247e0' // Azure Service Bus Data Receiver
    principalId: orderProcessingFunctionApp.outputs.principalId
  }
}
