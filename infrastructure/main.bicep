targetScope = 'subscription'

//********************************************************
// Parameters
//********************************************************

@description('Resource group name')
param resourceGroupName string = 'rg-example-scenario-azure-databricks-online-inference-containers'

@description('Databricks managed resource group name')
param mrgDatabricksName string = 'rgm-example-scenario-azure-databricks-online-inference-containers-databricks'

@description('Kubernetes managed resource group name')
param mrgKubernetesName string = 'rgm-example-scenario-azure-databricks-online-inference-containers-kubernetes'

@description('Location for resources')
param location string = 'australiaeast'

@description('Deploy Container Apps Environment')
param deployContainerAppsEnvironment bool = true

@description('Deploy Kubernetes service')
param deployKubernetesService bool = true

//********************************************************
// Variables
//********************************************************

var serviceSuffix = substring(uniqueString(resourceGroupName), 0, 5)

var resources = {
  applicationInsightsName: 'appi01${serviceSuffix}'
  containerRegistryName: 'cr01${serviceSuffix}'
  databricksName: 'dbw01${serviceSuffix}'
  logAnalyticsWorkspaceName: 'log01${serviceSuffix}'
  storageAccountName: 'st01${serviceSuffix}'
  userAssignedIdentityName: 'id01${serviceSuffix}'
  containerAppEnvironmnetStagingName: 'cae01${serviceSuffix}'
  containerAppEnvironmnetProductionName: 'cae02${serviceSuffix}'
  kubernetesServiceStagingName: 'aks01${serviceSuffix}'
  kubernetesServiceProductionName: 'aks02${serviceSuffix}'
}

//********************************************************
// Resources
//********************************************************

resource resourceGroup 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: resourceGroupName
  location: location
}

// ********************************************************
// Modules
// ********************************************************

module userAssignedIdentity './modules/user-assigned-identity.bicep' = {
  name: '${resources.userAssignedIdentityName}-deployment'
  scope: resourceGroup
  params: {
    name: resources.userAssignedIdentityName
    location: location
    tags: {
      environment: 'shared'
    }
  }
}

module storageAccount './modules/storage-account.bicep' = {
  name: '${resources.storageAccountName}-deployment'
  scope: resourceGroup
  params: {
    name: resources.storageAccountName
    location: location
    tags: {
      environment: 'shared'
    }
  }
}

module logAnalyticsWorkspace './modules/log-analytics-workspace.bicep' = {
  name: '${resources.logAnalyticsWorkspaceName}-deployment'
  scope: resourceGroup
  params: {
    name: resources.logAnalyticsWorkspaceName
    location: location
    tags: {
      environment: 'shared'
    }
    storageAccountId: storageAccount.outputs.id
  }
}

module applicationInsights './modules/application-insights.bicep' = {
  name: '${resources.applicationInsightsName}-deployment'
  scope: resourceGroup
  params: {
    name: resources.applicationInsightsName
    location: location
    tags: {
      environment: 'shared'
    }
    logAnalyticsWorkspaceId: logAnalyticsWorkspace.outputs.id
  }
}

module containerRegistry './modules/container-registry.bicep' = {
  name: '${resources.containerRegistryName}-deployment'
  scope: resourceGroup
  params: {
    name: resources.containerRegistryName
    location: location
    tags: {
      environment: 'shared'
    }
    logAnalyticsWorkspaceId: logAnalyticsWorkspace.outputs.id
    roles: [
      {
        principalId: userAssignedIdentity.outputs.principalId
        id: '7f951dda-4ed3-4680-a7ca-43fe172d538d' // ACR Pull role
      }
    ]
  }
}

module databricks './modules/databricks.bicep' = {
  name: '${resources.databricksName}-deployment'
  scope: resourceGroup
  params: {
    name: resources.databricksName
    location: location
    tags: {
      environment: 'shared'
    }
    managedResourceGroupName: mrgDatabricksName
    logAnalyticsWorkspaceId: logAnalyticsWorkspace.outputs.id
  }
}

var containerAppEnvironments = [
  { name: resources.containerAppEnvironmnetStagingName, environment: 'staging' }
  { name: resources.containerAppEnvironmnetProductionName, environment: 'production' }
]

module containerAppsEnvironment './modules/container-app-environment.bicep' = [
  for containerAppEnvironment in containerAppEnvironments: if (deployContainerAppsEnvironment) {
    name: '${containerAppEnvironment.name}-deployment'
    scope: resourceGroup
    params: {
      name: containerAppEnvironment.name
      location: location
      tags: {
        environment: containerAppEnvironment.environment
      }
      logAnalyticsWorkspaceName: logAnalyticsWorkspace.outputs.name
      logAnalyticsWorkspaceResourceGroupName: resourceGroup.name
    }
  }
]

var kubernetesServices = [
  { name: resources.kubernetesServiceStagingName, environment: 'staging' }
  { name: resources.kubernetesServiceProductionName, environment: 'production' }
]

module kubernetesService './modules/kubernetes-service.bicep' = [
  for kubernetesService in kubernetesServices: if (deployKubernetesService) {
    name: '${kubernetesService.name}-deployment'
    scope: resourceGroup
    params: {
      name: kubernetesService.name
      location: location
      tags: {
        environment: kubernetesService.environment
      }
      nodeResourceGroup: kubernetesService.environment == 'staging'
        ? '${mrgKubernetesName}-01'
        : '${mrgKubernetesName}-02'
      logAnalyticsWorkspaceId: logAnalyticsWorkspace.outputs.id
    }
  }
]

//********************************************************
// Outputs
//********************************************************

output storageAccountName string = storageAccount.outputs.name
output logAnalyticsWorkspaceName string = logAnalyticsWorkspace.outputs.name
output applicationInsightsName string = applicationInsights.outputs.name
output containerRegistryName string = containerRegistry.outputs.name
output databricksName string = databricks.outputs.name
output databricksHostname string = databricks.outputs.hostname
output userAssignedIdentityName string = userAssignedIdentity.outputs.name
output containerAppEnvironmnetStagingName string = containerAppsEnvironment[0].outputs.name
output containerAppEnvironmnetProductionName string = containerAppsEnvironment[1].outputs.name
output kubernetesServiceStagingName string = kubernetesService[0].outputs.name
output kubernetesServiceProductionName string = kubernetesService[1].outputs.name
