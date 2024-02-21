@description('Name of the app service')
param appServiceName string

@description('Location of the app service plan')
param appServiceLocation string

@description('Name of the slot that we want to create in our App Service')
param appServiceSlotName string

@description('Name of the app service plan')
param appServicePlanName string

@description('Version of Python')
param pythonVersion string

@description('Name of the Application Insights that this App will write logs to')
param appInsightsName string

@description('The application id of the app registration to manage authentication')
param authClientId string

@description('The client secret of the app registration to manage authentication')
@secure()
param authClientSecret string

@description('Tags.')
param tags object = {}

resource appInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: appInsightsName
}

var appSettings = [
  {
    name: 'MICROSOFT_PROVIDER_AUTHENTICATION_SECRET'   
    value: authClientSecret
  }
  {
    name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
    value: appInsights.properties.InstrumentationKey
  }
]

resource appServicePlan 'Microsoft.Web/serverfarms@2020-06-01' existing = {
  name: appServicePlanName
}

resource appService 'Microsoft.Web/sites@2021-02-01' = {
  name: appServiceName
  location: appServiceLocation
  kind: 'linux'
  tags: tags
  properties: {
    httpsOnly: true
    serverFarmId: appServicePlan.id
    siteConfig: {
      alwaysOn: true
      appCommandLine: 'gunicorn --bind=0.0.0.0 --timeout 600 --chdir root run:server'
      appSettings: appSettings
      linuxFxVersion: 'PYTHON|${pythonVersion}'
      minTlsVersion: '1.2'
    }
  }
  identity: {
    type: 'SystemAssigned'
  }

  resource blueSlot 'slots' = {
    name: appServiceSlotName
    location: appServiceLocation
    kind: 'linux'
    properties: {
      httpsOnly: true
      serverFarmId: appServicePlan.id
      siteConfig: {
        alwaysOn: true
        appCommandLine: 'gunicorn --bind=0.0.0.0 --timeout 600 --chdir root run:server'
        appSettings: appSettings
        linuxFxVersion: 'PYTHON|${pythonVersion}'
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
