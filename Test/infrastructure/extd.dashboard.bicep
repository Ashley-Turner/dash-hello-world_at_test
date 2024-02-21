@allowed([
  'dev'
  'tst'
  'prd'
])
param environment string
param workload string
param orgId string
param instance string = '01'
param dashboardName string
param pythonVersion string
param clientId string
@secure()
param clientSecret string

param locationAlias string
param location string = resourceGroup().location

var appServiceSlotName = 'staging'
var appServicePlanName = toLower('asp-${orgId}-${locationAlias}-${workload}-${environment}-${instance}')
var workloadIdentifier = dashboardName
var appServiceName = toLower('app-${orgId}-${locationAlias}-${workload}-${workloadIdentifier}-${environment}-${instance}')
var appInsightsName = toLower('appi-${orgId}-${locationAlias}-${workload}-${environment}-${instance}')

module appService 'modules/appService.bicep' = {
  name: 'appService'
  params: {
    appServiceLocation: location 
    appServiceName: appServiceName
    appServicePlanName: appServicePlanName
    appServiceSlotName: appServiceSlotName
    authClientId: clientId
    authClientSecret: clientSecret
    appInsightsName: appInsightsName
    pythonVersion: pythonVersion
  }
}
