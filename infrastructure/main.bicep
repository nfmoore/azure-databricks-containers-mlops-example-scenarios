//********************************************************
// General Parameters
//********************************************************

@description('Resource Location')
param resourceLocation string = resourceGroup().location

@description('Virtual Network IP Address Prefixes')
param vNetIPAddressPrefixesForFirstDeployment array = [
  '192.168.0.0/16'
]

@description('AKS Subnet IP Address Prefix')
param subnetAksIpAddressPrefixForFirstDeployment string = '192.168.0.0/24'

@description('App Gateway IP Address Prefix')
param subnetAppGwIpAddressPrefixForFirstDeployment string = '192.168.1.0/24'

@description('Virtual Network IP Address Prefixes')
param vNetIPAddressPrefixesForSecondDeployment array = [
  '192.167.0.0/16'
]

@description('AKS Subnet IP Address Prefix')
param subnetAksIpAddressPrefixForSecondDeployment string = '192.167.0.0/24'

@description('App Gateway IP Address Prefix')
param subnetAppGwIpAddressPrefixForSecondDeployment string = '192.167.1.0/24'

//********************************************************
// Modules
//********************************************************

module m_databricks './modules/databricks.bicep' = {
  name: 'm_databricks'
  params: {
    resourceInstance: '01'
    location: resourceLocation
  }
}

module m_microservices_01 './modules/microservices.bicep' = {
  name: 'm_microservices_01'
  params: {
    resourceInstance: '01'
    location: resourceLocation
    vNetIPAddressPrefixes: vNetIPAddressPrefixesForFirstDeployment
    subnetAksIpAddressPrefix: subnetAksIpAddressPrefixForFirstDeployment
    subnetAppGwIpAddressPrefix: subnetAppGwIpAddressPrefixForFirstDeployment
  }
}

module m_microservices_02 './modules/microservices.bicep' = {
  name: 'm_microservices_02'
  params: {
    resourceInstance: '02'
    location: resourceLocation
    vNetIPAddressPrefixes: vNetIPAddressPrefixesForSecondDeployment
    subnetAksIpAddressPrefix: subnetAksIpAddressPrefixForSecondDeployment
    subnetAppGwIpAddressPrefix: subnetAppGwIpAddressPrefixForSecondDeployment
    useExistingContainerRegistry: true
    useExistingLogAnalyticsWorkspace: true
    containerRegistryName: m_microservices_01.outputs.containerRegistryName
    logAnalyticsWorkspaceName: m_microservices_01.outputs.logAnalyticsWorkspaceName
  }
}
