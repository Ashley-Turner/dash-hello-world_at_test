@description('Name of the app service')
param appServiceName string

@description('Location of the app service plan')
param appServiceLocation string

@description('Name of the slot that we want to create in our App Service')
param appServiceSlotName string

@description('Name of the app service plan')
param appServicePlanName string

@description('Name of the Azure Container Registry that this App will pull images from')
param acrName string

@description('Name of the Application Insights that this App will write logs to')
param appInsightsName string

@description('The application id of the app registration to manage authentication')
param authClientId string

@description('The client secret of the app registration to manage authentication')
@secure()
param authClientSecret string

@description('The docker image and tag')
param dockerImageAndTag string = 'r:latest'

@description('Tags.')
param tags object = {}

// This is the ACR Pull Role Definition Id: https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#acrpull
var acrPullRoleDefinitionId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')

resource appInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: appInsightsName
}

var appSettings = [
  {
    name: 'WEBSITES_ENABLE_APP_SERVICE_STORAGE'
    value: 'false'
  }
  {
    name: 'MICROSOFT_PROVIDER_AUTHENTICATION_SECRET'   
    value: authClientSecret
  }
  {
    name: 'WEBSITES_CONTAINER_START_TIME_LIMIT'
    value: '600'
  }
  {
    name: 'DOCKER_REGISTRY_SERVER_URL'
    value: 'https://${containerRegistry.properties.loginServer}'
  }
  {
    name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
    value: appInsights.properties.InstrumentationKey
  }
]

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2021-09-01' existing = {
  name: acrName
}

resource appServicePlan 'Microsoft.Web/serverfarms@2020-06-01' existing = {
  name: appServicePlanName
}

resource appService 'Microsoft.Web/sites@2021-02-01' = {
  name: appServiceName
  location: appServiceLocation
  kind: 'app,linux,container'
  tags: tags
  properties: {
    serverFarmId: appServicePlan.id
    siteConfig: {
      alwaysOn: true
      appSettings: appSettings
      acrUseManagedIdentityCreds: true
      linuxFxVersion: 'DOCKER|${containerRegistry.properties.loginServer}/${dockerImageAndTag}'
      minTlsVersion: '1.2'
    }
  }
  identity: {
    type: 'SystemAssigned'
  }

  resource blueSlot 'slots' = {
    name: appServiceSlotName
    location: appServiceLocation
    kind: 'app,linux,container'
    properties: {
      httpsOnly: true
      serverFarmId: appServicePlan.id
      siteConfig: {
        alwaysOn: true
        acrUseManagedIdentityCreds: true
        appSettings: appSettings
        minTlsVersion: '1.2'
      }
    }
    identity: {
      type: 'SystemAssigned'
    }
  }

  resource easyauth_config 'config' = {
    name: 'authsettingsV2'    
    properties: {
      httpSettings: {
        requireHttps: true
      }
      globalValidation: {
        requireAuthentication: true
        redirectToProvider: 'azureActiveDirectory'
        unauthenticatedClientAction: 'RedirectToLoginPage'
      }
      platform: {
        enabled: true
      }
      login: {
        tokenStore: {
          enabled: true
        }
      }
      identityProviders: {
        azureActiveDirectory: {
          enabled: true
          registration: {
            clientId: authClientId
            clientSecretSettingName: 'MICROSOFT_PROVIDER_AUTHENTICATION_SECRET'
            openIdIssuer: 'https://sts.windows.net/${subscription().tenantId}/v2.0'
          }
          validation: {
            allowedAudiences: [
              'api://${authClientId}'
            ]
          }
        }
      }
    }
  }
}

resource appServiceAppSettings 'Microsoft.Web/sites/config@2020-06-01' = {
  parent: appService
  name: 'logs'
  properties: {
    applicationLogs: {
      fileSystem: {
        level: 'Warning'
      }
    }
    httpLogs: {
      fileSystem: {
        retentionInMb: 40
        enabled: true
      }
    }
    failedRequestsTracing: {
      enabled: true
    }
    detailedErrorMessages: {
      enabled: true
    }
  }
}

resource appServiceAcrPullRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-08-01-preview' = {
  scope: containerRegistry
  name: guid(containerRegistry.id, appService.id, acrPullRoleDefinitionId)
  properties: {
    principalId: appService.identity.principalId
    roleDefinitionId: acrPullRoleDefinitionId
    principalType: 'ServicePrincipal'
  }
}

resource appServiceSlotAcrPullRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-08-01-preview' = {
  scope: containerRegistry
  name: guid(containerRegistry.id, appService::blueSlot.id, acrPullRoleDefinitionId)
  properties: {
    principalId: appService::blueSlot.identity.principalId
    roleDefinitionId: acrPullRoleDefinitionId
    principalType: 'ServicePrincipal'
  }
}
