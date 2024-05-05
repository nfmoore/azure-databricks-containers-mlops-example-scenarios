//********************************************************
// Parameters
//********************************************************

@description('Name of the Storage service')
param name string

@description('Location for Storage service')
param location string = resourceGroup().location

@description('Tags for the Storage service')
param tags object = {}

@description('Role assignments for the Storage service')
param roles array = []

@description('Enable hierarchical namespace')
param enableHns bool = false

//********************************************************
// Resources
//********************************************************

resource stNew 'Microsoft.Storage/storageAccounts@2022-05-01' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    isHnsEnabled: enableHns
    minimumTlsVersion: 'TLS1_2'
  }
}

resource roleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for role in roles: {
    name: guid(name, role.principalId, role.id)
    scope: stNew
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

output name string = stNew.name
output id string = stNew.id
