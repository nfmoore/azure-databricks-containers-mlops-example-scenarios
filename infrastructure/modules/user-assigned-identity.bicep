//********************************************************
// Parameters
//********************************************************

@description('Name of the User Assigned Identity service')
param name string

@description('Location for User Assigned Identity service')
param location string = resourceGroup().location

@description('Tags for the User Assigned Identity service')
param tags object = {}

//********************************************************
// Resources
//********************************************************

resource idNew 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: name
  location: location
  tags: tags
}

//********************************************************
// Outputs
//********************************************************

output id string = idNew.id
output name string = idNew.name
output principalId string = idNew.properties.principalId
