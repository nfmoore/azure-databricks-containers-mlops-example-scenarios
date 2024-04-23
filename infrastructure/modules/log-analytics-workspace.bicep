//********************************************************
// Parameters
//********************************************************

@description('Name of the Log Analytics workspace')
param name string

@description('Location for Log Analytics workspace')
param location string = resourceGroup().location

@description('Tags for the Log Analytics workspace')
param tags object = {}

@description('Role assignments for the Log Analytics workspace')
param roles array = []

@description('Storage account ID to link to the Log Analytics workspace')
param storageAccountId string = ''

//********************************************************
// Resources
//********************************************************

resource logNew 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    retentionInDays: 30
    sku: {
      name: 'Standalone'
    }
  }

  resource linkedStAlerts 'linkedStorageAccounts@2020-08-01' = {
    name: 'Alerts'
    properties: {
      storageAccountIds: [
        storageAccountId
      ]
    }
  }

  resource linkedStCustomLogs 'linkedStorageAccounts@2020-08-01' = {
    name: 'CustomLogs'
    properties: {
      storageAccountIds: [
        storageAccountId
      ]
    }
  }

  resource linkedStIngestion 'linkedStorageAccounts@2020-08-01' = {
    name: 'Ingestion'
    properties: {
      storageAccountIds: [
        storageAccountId
      ]
    }
  }

  resource linkedStQuery 'linkedStorageAccounts@2020-08-01' = {
    name: 'Query'
    properties: {
      storageAccountIds: [
        storageAccountId
      ]
    }
  }
}

resource roleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for role in roles: {
    name: guid(name, role.principalId, role.id)
    scope: logNew
    properties: {
      roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', role.id)
      principalId: role.principalId
      principalType: contains(role, 'type') ? role.type : 'ServicePrincipal'
    }
  }
]

//********************************************************
// Outputs
//********************************************************

output name string = logNew.name
output id string = logNew.id
