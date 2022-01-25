//********************************************************
// General Parameters
//********************************************************

@description('Workload Identifier')
param workloadIdentifier string = substring(uniqueString(resourceGroup().id), 0, 6)

@description('Resource Instance')
param resourceInstance string = '001'

@description('The location of resources')
param location string = resourceGroup().location

//********************************************************
// Resource Config Parameters
//********************************************************

//Contianer Registry Parameters
@description('Container Registry Name')
param containerRegistryName string = 'cr${workloadIdentifier}${resourceInstance}'

@description('Create new Log Analytics Workspace ')
param useExistingContainerRegistry bool = false

@description('Log Analytics Workspace SKU')
param containerRegistryResourceGroupName string = resourceGroup().name

@description('Enable Container Registry admin user')
param adminUserEnabled bool = true

//----------------------------------------------------------------------

//Log Analytics Workspace Parameters
@description('Log Analytics Workspace Name')
param logAnalyticsWorkspaceName string = 'law${workloadIdentifier}${resourceInstance}'

@description('Create new Log Analytics Workspace ')
param useExistingLogAnalyticsWorkspace bool = false

@description('Log Analytics Workspace SKU')
param logAnalyticsWorkspaceResourceGroupName string = resourceGroup().name

@description('Log Analytics Workspace SKU')
param logAnalyticsWorkspaceSKU string = 'PerGB2018'

@description('Log Analytics Workspace Daily Quota')
param logAnalyticsWorkspaceDailyQuota int = 1

@description('Log Analytics Workspace Retention Period')
param logAnalyticsWorkspaceRetentionPeriod int = 30

//----------------------------------------------------------------------

//Kubernetes Service Parameters
@description('The name of the Managed Cluster resource')
param kubernetesServiceClusterName string = 'aks${workloadIdentifier}${resourceInstance}'

@description('DNS prefix to use with hosted Kubernetes API server FQDN')
param dnsPrefix string = 'dns'

@description('Disk size (in GiB) to provision for each of the agent pool nodes')
@minValue(0)
@maxValue(1023)
param osDiskSizeGB int = 0

@description('Kubernetes cluster version')
param kubernetesVersion string = '1.21.7'

@description('Network plugin used for building Kubernetes network.')
@allowed([
  'azure'
  'kubenet'
])
param networkPlugin string = 'kubenet'

@description('Enable RBAC.')
param enableRBAC bool = true

@description('Enable private network access to the Kubernetes cluster')
param enablePrivateCluster bool = false

@description('Enable application routing')
param enableHttpApplicationRouting bool = false

@description('Enable Azure Policy addon')
param enableAzurePolicy bool = false

@description('Enable application gateway')
param enableIngressApplicationGateway bool = true

@description('Application gateway name')
param ingressApplicationGatewayName string = 'ingress-appgateway'

@description('Application gateway subnet prefix')
param ingressApplicationGatewaySubnetPrefix string = '10.1.0.0/16'

@description('Cluster Virtual Machine size')
param agentVMSize string = 'Standard_DS2_v2'

@description('Number of nodes for the cluster')
@minValue(1)
@maxValue(50)
param agentCount int = 3

@description('Min number of nodes for the cluster')
@minValue(1)
@maxValue(50)
param minAgentCount int = 1

@description('Max number of nodes for the cluster')
@minValue(1)
@maxValue(50)
param maxAgentCount int = 3

//********************************************************
// Variables
//********************************************************

var azureRbacContributorRoleId = 'b24988ac-6180-42a0-ab88-20f7382dd24c' //Contributor

//********************************************************
// Resources
//********************************************************

//Container Registry
resource r_containerRegistry 'Microsoft.KeyVault/vaults@2021-04-01-preview' existing = if (useExistingContainerRegistry == true) {
  name: containerRegistryName
  scope: resourceGroup(containerRegistryResourceGroupName)
}

resource r_newContainerRegistry 'Microsoft.ContainerRegistry/registries@2019-05-01' = if (useExistingContainerRegistry == false) {
  name: containerRegistryName
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: adminUserEnabled
  }
}

// Deploy Log Analytics Workspace
resource r_keyVault 'Microsoft.KeyVault/vaults@2021-04-01-preview' existing = if (useExistingLogAnalyticsWorkspace == true) {
  name: logAnalyticsWorkspaceName
  scope: resourceGroup(logAnalyticsWorkspaceResourceGroupName)
}

resource r_newLogAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2020-03-01-preview' = if (useExistingLogAnalyticsWorkspace == false) {
  name: logAnalyticsWorkspaceName
  location: location
  properties: {
    retentionInDays: logAnalyticsWorkspaceRetentionPeriod
    sku: {
      name: logAnalyticsWorkspaceSKU
    }
    workspaceCapping: {
      dailyQuotaGb: logAnalyticsWorkspaceDailyQuota
    }
  }
}

//Kubernetes Service
resource r_aks 'Microsoft.ContainerService/managedClusters@2021-07-01' = {
  name: kubernetesServiceClusterName
  location: location
  tags: {}
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    kubernetesVersion: kubernetesVersion
    enableRBAC: enableRBAC
    dnsPrefix: dnsPrefix
    agentPoolProfiles: [
      {
        name: 'agentpool'
        osDiskSizeGB: osDiskSizeGB
        count: agentCount
        enableAutoScaling: true
        minCount: minAgentCount
        maxCount: maxAgentCount
        vmSize: agentVMSize
        osType: 'Linux'
        mode: 'System'
        type: 'VirtualMachineScaleSets'
        maxPods: 110
      }
    ]
    networkProfile: {
      loadBalancerSku: 'standard'
      networkPlugin: networkPlugin
    }
    apiServerAccessProfile: {
      enablePrivateCluster: enablePrivateCluster
    }
    addonProfiles: {
      httpApplicationRouting: {
        enabled: enableHttpApplicationRouting
      }
      azurepolicy: {
        enabled: enableAzurePolicy
      }
      ingressApplicationGateway: {
        enabled: enableIngressApplicationGateway
        config: {
          applicationGatewayName: ingressApplicationGatewayName
          subnetPrefix: ingressApplicationGatewaySubnetPrefix
        }
      }
    }
  }
}

//********************************************************
// RBAC Role Assignments
//********************************************************

// Assign Contributor Role to AKS Service MSI in the Container Registry
resource acrName_Microsoft_Authorization_guidValue 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(kubernetesServiceClusterName, containerRegistryName, 'Contributor')
  properties: {
    principalId: r_aks.identity.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', azureRbacContributorRoleId)
  }
}

//********************************************************
// Outputs
//********************************************************

output controlPlaneFQDN string = r_aks.properties.fqdn
output containerRegistryName string = r_containerRegistry.name
output logAnalyticsWorkspaceName string = r_newLogAnalyticsWorkspace.name
