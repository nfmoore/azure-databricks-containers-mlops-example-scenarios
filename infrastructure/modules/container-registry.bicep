//********************************************************
// Parameters
//********************************************************

@description('Name of the Container Registry service')
param name string

@description('Location for Container Registry service')
param location string = resourceGroup().location

@description('Tags for the Container Registry service')
param tags object = {}

@description('Role assignments for the Container Registry service')
param roles array = []

@description('Log Analytics workspace ID for diagnostics')
param logAnalyticsWorkspaceId string = ''

//********************************************************
// Resources
//********************************************************

resource crNew 'Microsoft.ContainerRegistry/registries@2022-12-01' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    adminUserEnabled: true
  }
}

resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'all-logs-all-metrics'
  scope: crNew
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

resource roleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for role in roles: {
    name: guid(name, role.principalId, role.id)
    scope: crNew
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

output name string = crNew.name
output id string = crNew.id
