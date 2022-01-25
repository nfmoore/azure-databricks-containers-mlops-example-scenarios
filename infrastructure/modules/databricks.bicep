//********************************************************
// General Parameters
//********************************************************

@description('Workload Identifier')
param workloadIdentifier string = substring(uniqueString(resourceGroup().id), 0, 6)

@description('Resource Instance')
param resourceInstance string = '001'

@description('Resource Location')
param resourceLocation string = resourceGroup().location

//********************************************************
// Resource Config Parameters
//********************************************************

//Azure EventHub Namespace Parameters
@description('Databricks Workspace Name')
param databricksWorkspaceName string = 'dbw${workloadIdentifier}${resourceInstance}'

@description('Databricks Managed Resource Group Name')
param databricksManagedResourceGroupName string = '${resourceGroup().name}-dbw-mngd'

@description('The pricing tier of workspace.')
@allowed([
  'standard'
  'premium'
])
param pricingTier string = 'standard'

@description('Control Deployment of Data Lake Storage Account')
param deployDataLakeAccount bool = true

@description('Data Lake Account Name')
param dataLakeAccountName string = 'st${workloadIdentifier}${resourceInstance}'

@description('Data Lake Storage Account SKU')
param dataLakeAccountSKU string = 'Standard_LRS'

@description('Data Lake Bronze Zone Container Name')
param dataLakeBronzeZoneName string = 'raw'

@description('Data Lake Silver Zone Container Name')
param dataLakeSilverZoneName string = 'trusted'

@description('Data Lake Gold Zone Container Name')
param dataLakeGoldZoneName string = 'curated'

@description('Data Lake Sandbox Zone Container Name')
param dataLakeSandboxZoneName string = 'sandbox'

@description('Allow Shared Key Access')
param allowSharedKeyAccess bool = false

//********************************************************
// Resources
//********************************************************

// Databricks Workspace
resource r_databricksWorkspace 'Microsoft.Databricks/workspaces@2018-04-01' = {
  name: databricksWorkspaceName
  location: resourceLocation
  sku: {
    name: pricingTier
  }
  properties: {
    managedResourceGroupId: r_databricksManagedResourceGroup.id
    parameters: {
      enableNoPublicIp: {
        value: false
      }
    }
  }
}

resource r_databricksManagedResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' existing = {
  scope: subscription()
  name: databricksManagedResourceGroupName
}

// Data Lake Storage Account
resource r_dataLakeStorageAccount 'Microsoft.Storage/storageAccounts@2021-02-01' = if (deployDataLakeAccount == true) {
  name: dataLakeAccountName
  location: resourceLocation
  properties: {
    isHnsEnabled: true
    accessTier: 'Hot'
    allowBlobPublicAccess: true
    supportsHttpsTrafficOnly: true
    allowSharedKeyAccess: allowSharedKeyAccess
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
      resourceAccessRules: [
        {
          tenantId: subscription().tenantId
          resourceId: r_databricksWorkspace.id
        }
      ]
    }
  }
  kind: 'StorageV2'
  sku: {
    name: dataLakeAccountSKU
  }
}

var privateContainerNames = [
  dataLakeBronzeZoneName
  dataLakeSilverZoneName
  dataLakeGoldZoneName
  dataLakeSandboxZoneName
]

resource r_dataLakePrivateContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-02-01' = [for containerName in privateContainerNames: if (deployDataLakeAccount == true) {
  name: '${r_dataLakeStorageAccount.name}/default/${containerName}'
}]

//********************************************************
// Outputs
//********************************************************
