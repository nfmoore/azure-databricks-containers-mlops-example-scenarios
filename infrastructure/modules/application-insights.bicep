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

@description('Log Analytics workspace ID for diagnostics')
param logAnalyticsWorkspaceId string = ''

//********************************************************
// Resources
//********************************************************

resource appiNew 'Microsoft.Insights/components@2020-02-02' = {
  name: name
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    Flow_Type: 'Bluefield'
    IngestionMode: 'LogAnalytics'
    RetentionInDays: 30
    WorkspaceResourceId: logAnalyticsWorkspaceId
  }
}

resource roleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for role in roles: {
    name: guid(name, role.principalId, role.id)
    scope: appiNew
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

output name string = appiNew.name
output id string = appiNew.id
