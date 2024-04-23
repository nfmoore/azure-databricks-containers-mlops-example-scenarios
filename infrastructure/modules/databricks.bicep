//********************************************************
// Parameters
//********************************************************

@description('Name of the Databricks service')
param name string

@description('Managed resource group for the Databricks service')
param managedResourceGroupName string

@description('Location for the Databricks service')
param location string = resourceGroup().location

@description('Tags for the Databricks service')
param tags object = {}

@description('Role assignments for the Databricks service')
param roles array = []

@description('Log Analytics workspace ID for diagnostics')
param logAnalyticsWorkspaceId string = ''

//********************************************************
// Resources
//********************************************************

resource managedRg 'Microsoft.Resources/resourceGroups@2020-06-01' existing = {
  scope: subscription()
  name: managedResourceGroupName
}

resource dbwNew 'Microsoft.Databricks/workspaces@2023-02-01' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: 'premium'
  }
  properties: {
    parameters: {}
    managedResourceGroupId: managedRg.id
  }
}

resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'all-logs-all-metrics'
  scope: dbwNew
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
  }
}

resource roleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for role in roles: {
    name: guid(name, role.principalId, role.id)
    scope: dbwNew
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

output name string = dbwNew.name
output id string = dbwNew.id
output hostname string = dbwNew.properties.workspaceUrl
