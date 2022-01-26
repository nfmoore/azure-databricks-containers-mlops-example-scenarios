//********************************************************
// Modules
//********************************************************

module m_databricks './modules/databricks.bicep' = {
  name: 'm_databricks'
  params: {
    resourceInstance: '01'
  }
}

module m_microservices_01 './modules/microservices.bicep' = {
  name: 'm_microservices_01'
  params: {
    resourceInstance: '01'
  }
}

module m_microservices_02 './modules/microservices.bicep' = {
  name: 'm_microservices_02'
  params: {
    resourceInstance: '02'
    useExistingContainerRegistry: true
    useExistingLogAnalyticsWorkspace: true
    containerRegistryName: m_microservices_01.outputs.containerRegistryName
    logAnalyticsWorkspaceName: m_microservices_01.outputs.logAnalyticsWorkspaceName
  }
}
