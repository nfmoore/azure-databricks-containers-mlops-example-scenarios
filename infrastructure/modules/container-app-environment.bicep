//********************************************************
// Parameters
//********************************************************

@description('Name of the Application Insights service')
param name string

@description('Location for Application Insights service')
param location string = resourceGroup().location

@description('Tags for the Application Insights service')
param tags object = {}

@description('Role assignments for the Application Insights service')
param roles array = []

@description('Log Analytics workspace name')
param logAnalyticsWorkspaceName string = ''

@description('Log Analytics workspace  resource group name')
param logAnalyticsWorkspaceResourceGroupName string = resourceGroup().name

//********************************************************
// Resources
//********************************************************

resource logExisting 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  scope: resourceGroup(logAnalyticsWorkspaceResourceGroupName)
  name: logAnalyticsWorkspaceName
}

resource caeNew 'Microsoft.App/managedEnvironments@2023-05-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logExisting.properties.customerId
        sharedKey: logExisting.listKeys().primarySharedKey
      }
    }
  }
}

resource roleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for role in roles: {
    name: guid(name, role.principalId, role.id)
    scope: caeNew
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

output name string = caeNew.name
output id string = caeNew.id
