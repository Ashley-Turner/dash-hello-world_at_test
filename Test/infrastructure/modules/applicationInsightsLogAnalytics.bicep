@description('Name of the Application Insights')
param applicationInsightsName string

@description('Application Insight Location.')
param applicationInsightsLocation string

@description('Name of the Application Insights')
param logAnalyticsName string

@description('Name of the Application Insights')
param logRetentionDays int = 90

@description('Tags.')
param tags object = {}

resource appInsights 'Microsoft.Insights/components@2020-02-02-preview' = {
  name: applicationInsightsName
  location: applicationInsightsLocation
  kind: 'web'
  properties: {
    Application_Type: 'web'
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
    WorkspaceResourceId: logAnalyticsWorkspace.id
  }
  tags:tags
}

output instrumentationKey string = appInsights.properties.InstrumentationKey

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2020-08-01' = {
  name: logAnalyticsName
  location: applicationInsightsLocation
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: logRetentionDays
    features: {
      searchVersion: 1
      legacy: 0
      enableLogAccessUsingOnlyResourcePermissions: true
    }
  }
}
