targetScope = 'subscription'

//********************************************************
// Parameters
//********************************************************

@description('Resource group name')
param resourceGroupName string = 'rg-example-scenario-azure-databricks-online-inference-containers'

@description('Databricks managed resource group name')
param mrgDatabricksName string = 'rgm-example-scenario-azure-databricks-online-inference-containers-databricks'

@description('Location for resources')
param location string = 'Australia East'

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

//********************************************************
// Outputs
//********************************************************
