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

@description('Log Analytics Workspace Resource Group Name')
param containerRegistryResourceGroupName string = resourceGroup().name

@description('Enable Container Registry admin user')
param adminUserEnabled bool = true

//----------------------------------------------------------------------

//Log Analytics Workspace Parameters
@description('Log Analytics Workspace Name')
param logAnalyticsWorkspaceName string = 'law${workloadIdentifier}${resourceInstance}'

@description('Create new Log Analytics Workspace ')
param useExistingLogAnalyticsWorkspace bool = false

@description('Log Analytics Workspace Resource Group Name')
param logAnalyticsWorkspaceResourceGroupName string = resourceGroup().name

//----------------------------------------------------------------------

//Virtual Network Parameters
@description('Virtual Network Name')
param vNetName string = 'vnet${workloadIdentifier}${resourceInstance}'

@description('Virtual Network IP Address Prefixes')
param vNetIPAddressPrefixes array = [
  '192.168.0.0/16'
]

@description('AKS Subnet Name')
param subnetAksName string = 'akssubnet'

@description('App Gateway Subnet Name')
param subnetAppGwName string = 'appgwsubnet'

@description('AKS Subnet IP Address Prefix')
param subnetAksIpAddressPrefix string = '192.168.0.0/24'

@description('App Gateway IP Address Prefix')
param subnetAppGwIpAddressPrefix string = '192.168.1.0/24'

//----------------------------------------------------------------------

//Kubernetes Service Parameters
@description('The name of the Managed Cluster resource')
param kubernetesServiceClusterName string = 'aks${workloadIdentifier}${resourceInstance}'

@description('DNS prefix to use with hosted Kubernetes API server FQDN')
param dnsPrefix string = 'dns'

//----------------------------------------------------------------------

//Public IP Address Parameters
@description('The name of the Public IP Address')
param publicIpAddressName string = 'pubip${workloadIdentifier}${resourceInstance}'

//----------------------------------------------------------------------

//Application Gateway Parameters
@description('The name of the Application Gateway')
param applicationGatewayName string = 'appgw${workloadIdentifier}${resourceInstance}'

//********************************************************
// Variables
//********************************************************

var azureRbacContributorRoleId = 'b24988ac-6180-42a0-ab88-20f7382dd24c' //Contributor
var applicationGatewayId = resourceId('Microsoft.Network/applicationGateways', applicationGatewayName) //Workaround for referencing App Gateway ID

//********************************************************
// Resources
//********************************************************

//Container Registry
resource r_containerRegistry 'Microsoft.ContainerRegistry/registries@2019-05-01' existing = if (useExistingContainerRegistry == true) {
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
resource r_logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2020-03-01-preview' existing = if (useExistingLogAnalyticsWorkspace == true) {
  name: logAnalyticsWorkspaceName
  scope: resourceGroup(logAnalyticsWorkspaceResourceGroupName)
}

resource r_newLogAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2020-03-01-preview' = if (useExistingLogAnalyticsWorkspace == false) {
  name: logAnalyticsWorkspaceName
  location: location
  properties: {
    retentionInDays: 30
    sku: {
      name: 'PerGB2018'
    }
    workspaceCapping: {
      dailyQuotaGb: 1
    }
  }
}

// Deploy Virtual Network
resource r_vNet 'Microsoft.Network/virtualNetworks@2020-11-01' = {
  name: vNetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: vNetIPAddressPrefixes
    }
  }
}

resource r_subNetAks 'Microsoft.Network/virtualNetworks/subnets@2020-11-01' = {
  name: subnetAksName
  parent: r_vNet
  properties: {
    addressPrefix: subnetAksIpAddressPrefix
    privateEndpointNetworkPolicies: 'Enabled'
    privateLinkServiceNetworkPolicies: 'Enabled'
  }

  dependsOn: [ r_subNetAppGw ]
}

resource r_subNetAppGw 'Microsoft.Network/virtualNetworks/subnets@2020-11-01' = {
  name: subnetAppGwName
  parent: r_vNet
  properties: {
    addressPrefix: subnetAppGwIpAddressPrefix
    privateEndpointNetworkPolicies: 'Enabled'
    privateLinkServiceNetworkPolicies: 'Enabled'
  }
}

//Kubernetes Service
resource r_aks 'Microsoft.ContainerService/managedClusters@2022-04-02-preview' = {
  name: kubernetesServiceClusterName
  location: location
  sku: {
    name: 'Basic'
    tier: 'Free'
  }
  tags: {}
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    kubernetesVersion: '1.23.12'
    dnsPrefix: dnsPrefix
    agentPoolProfiles: [
      {
        name: 'agentpool'
        count: 2
        vmSize: 'Standard_B2s'
        osDiskSizeGB: 128
        osDiskType: 'Managed'
        kubeletDiskType: 'OS'
        vnetSubnetID: r_subNetAks.id
        maxPods: 110
        type: 'VirtualMachineScaleSets'
        maxCount: 2
        minCount: 1
        enableAutoScaling: true
        orchestratorVersion: '1.22.6'
        enableNodePublicIP: false
        mode: 'System'
        osType: 'Linux'
        osSKU: 'Ubuntu'
        enableFIPS: false
      }
    ]
    servicePrincipalProfile: {
      clientId: 'msi'
    }
    apiServerAccessProfile: {
      enablePrivateCluster: false
    }
    addonProfiles: {
      azureKeyvaultSecretsProvider: {
        enabled: false
      }
      azurepolicy: {
        enabled: false
      }
      httpApplicationRouting: {
        enabled: false
      }
      ingressApplicationGateway: {
        enabled: true
        config: {
          applicationGatewayId: applicationGatewayId
          effectiveApplicationGatewayId: applicationGatewayId
        }
      }
      omsAgent: {
        enabled: true
        config: {
          logAnalyticsWorkspaceResourceID: useExistingLogAnalyticsWorkspace ? r_logAnalyticsWorkspace.id : r_newLogAnalyticsWorkspace.id
        }
      }
    }
    nodeResourceGroup: '${resourceGroup().name}-${resourceInstance}-mngd'
    enableRBAC: true
    networkProfile: {
      networkPlugin: 'azure'
      loadBalancerSku: 'Standard'
      loadBalancerProfile: {
        managedOutboundIPs: {
          count: 1
        }
        effectiveOutboundIPs: [
          {
            id: r_publicIpAddress.id
          }
        ]
      }
      serviceCidr: '10.0.0.0/16'
      dnsServiceIP: '10.0.0.10'
      dockerBridgeCidr: '172.17.0.1/16'
      outboundType: 'loadBalancer'
    }
    storageProfile: {
      diskCSIDriver: {
        enabled: true
        version: 'v1'
      }
      fileCSIDriver: {
        enabled: true
      }
      snapshotController: {
        enabled: true
      }
    }
    oidcIssuerProfile: {
      enabled: false
    }
  }
}

//Public IP Address
resource r_publicIpAddress 'Microsoft.Network/publicIPAddresses@2020-11-01' = {
  name: publicIpAddressName
  location: location
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'
    idleTimeoutInMinutes: 4
  }
}

//Application Gateway
resource r_applicationGateway 'Microsoft.Network/applicationGateways@2020-11-01' = {
  name: applicationGatewayName
  location: location
  properties: {
    sku: {
      name: 'Standard_v2'
      tier: 'Standard_v2'
    }
    gatewayIPConfigurations: [
      {
        name: 'appGatewayIpConfig'
        properties: {
          subnet: {
            id: r_subNetAppGw.id
          }
        }
      }
    ]
    frontendIPConfigurations: [
      {
        name: 'appGwPublicFrontendIp'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: r_publicIpAddress.id
          }
        }
      }
    ]
    frontendPorts: [
      {
        name: 'port_80'
        properties: {
          port: 80
        }
      }
    ]
    backendAddressPools: [
      {
        name: 'defaultaddresspool'
        properties: {
          backendAddresses: []
        }
      }
    ]
    backendHttpSettingsCollection: [
      {
        name: 'defaulthttpsetting'
        properties: {
          port: 80
          protocol: 'Http'
          cookieBasedAffinity: 'Disabled'
          pickHostNameFromBackendAddress: false
          requestTimeout: 30
          probe: {
            id: '${applicationGatewayId}/probes/defaultprobe-Http'
          }
        }
      }
    ]
    httpListeners: [
      {
        name: 'fl-e1903c8aa3446b7b3207aec6d6ecba8a'
        properties: {
          frontendIPConfiguration: {
            id: '${applicationGatewayId}/frontendIPConfigurations/appGwPublicFrontendIp'
          }
          frontendPort: {
            id: '${applicationGatewayId}/frontendPorts/port_80'
          }
          protocol: 'Http'
          hostNames: []
          requireServerNameIndication: false
        }
      }
    ]
    urlPathMaps: []
    requestRoutingRules: [
      {
        name: 'rr-e1903c8aa3446b7b3207aec6d6ecba8a'
        properties: {
          ruleType: 'Basic'
          httpListener: {
            id: '${applicationGatewayId}/httpListeners/fl-e1903c8aa3446b7b3207aec6d6ecba8a'
          }
          backendAddressPool: {
            id: '${applicationGatewayId}/backendAddressPools/defaultaddresspool'
          }
          backendHttpSettings: {
            id: '${applicationGatewayId}/backendHttpSettingsCollection/defaulthttpsetting'
          }
        }
      }
    ]
    probes: [
      {
        name: 'defaultprobe-Http'
        properties: {
          protocol: 'Http'
          host: 'localhost'
          path: '/'
          interval: 30
          timeout: 30
          unhealthyThreshold: 3
          pickHostNameFromBackendHttpSettings: false
          minServers: 0
          match: {}
        }
      }
      {
        name: 'defaultprobe-Https'
        properties: {
          protocol: 'Https'
          host: 'localhost'
          path: '/'
          interval: 30
          timeout: 30
          unhealthyThreshold: 3
          pickHostNameFromBackendHttpSettings: false
          minServers: 0
          match: {}
        }
      }
    ]
    enableHttp2: false
    autoscaleConfiguration: {
      minCapacity: 0
      maxCapacity: 3
    }
  }
}

//********************************************************
// RBAC Role Assignments
//********************************************************

resource r_aksContainerRegistryAssignment 'Microsoft.Authorization/roleAssignments@2020-08-01-preview' = if (useExistingContainerRegistry == false) {
  name: guid(kubernetesServiceClusterName, containerRegistryName, 'contributor')
  scope: useExistingContainerRegistry ? r_containerRegistry : r_newContainerRegistry
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', azureRbacContributorRoleId)
    principalId: r_aks.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource r_aksAppGatewayAssignment 'Microsoft.Authorization/roleAssignments@2020-08-01-preview' = {
  name: guid(kubernetesServiceClusterName, applicationGatewayName, 'contributor')
  scope: resourceGroup()
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', azureRbacContributorRoleId)
    principalId: r_aks.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource r_agicAppGatewayAssignment 'Microsoft.Authorization/roleAssignments@2020-08-01-preview' = {
  name: guid(kubernetesServiceClusterName, 'agic', 'contributor')
  scope: resourceGroup()
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', azureRbacContributorRoleId)
    principalId: r_aks.properties.addonProfiles.ingressApplicationGateway.identity.objectId
    principalType: 'ServicePrincipal'
  }
}

//********************************************************
// Outputs
//********************************************************

output controlPlaneFQDN string = r_aks.properties.fqdn
output containerRegistryName string = r_containerRegistry.name
output logAnalyticsWorkspaceName string = r_newLogAnalyticsWorkspace.name
