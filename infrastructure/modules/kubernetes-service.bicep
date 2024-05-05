//********************************************************
// Parameters
//********************************************************

@description('Name of the Kubernetes Service service')
param name string

@description('Location for Kubernetes Service service')
param location string = resourceGroup().location

@description('Tags for the Kubernetes Service service')
param tags object = {}

@description('Role assignments for the Kubernetes Service service')
param roles array = []

@description('Managed resource group for the node resources')
param nodeResourceGroup string

@description('Log Analytics workspace ID for diagnostics')
param logAnalyticsWorkspaceId string

//********************************************************
// Resources
//********************************************************

resource aksNew 'Microsoft.ContainerService/managedClusters@2024-01-01' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: 'Base'
    tier: 'Free'
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    dnsPrefix: '${name}-dns'
    agentPoolProfiles: [
      {
        name: 'agentpool'
        osDiskSizeGB: 128
        count: 2
        vmSize: 'Standard_B2s'
        osType: 'Linux'
        mode: 'System'
        osSKU: 'AzureLinux'
      }
    ]
    enableRBAC: true
    nodeResourceGroup: nodeResourceGroup
    addonProfiles: {
      omsagent: {
        enabled: true
        config: {
          logAnalyticsWorkspaceResourceID: logAnalyticsWorkspaceId
          useAADAuth: 'true'
        }
      }
    }
  }
}

resource roleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for role in roles: {
    name: guid(name, role.principalId, role.id)
    scope: aksNew
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

output name string = aksNew.name
output id string = aksNew.id
