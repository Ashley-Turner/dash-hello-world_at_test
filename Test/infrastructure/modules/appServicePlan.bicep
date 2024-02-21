@description('Name of the app service plan')
param appServicePlanName string

@description('Location of the app service plan')
param appServicePlanLocation string

@description('Name of the app service plan SKU')
param appServicePlanSkuName string

@description('Capacity of the app service plan SKU')
param appServicePlanCapacity int

@description('Type of the app service plan OS')
param appServicePlanKind string = 'linux'

@description('Tags.')
param tags object = {}

resource appServicePlan 'Microsoft.Web/serverfarms@2021-02-01' = {
  name: appServicePlanName
  tags: tags
  location: appServicePlanLocation
  sku: {
    name: appServicePlanSkuName
    capacity: appServicePlanCapacity
  }
  kind: appServicePlanKind
  properties: {
    reserved: true
  }
}

resource scaling 'Microsoft.Insights/autoscalesettings@2021-05-01-preview' = {
  name: '${appServicePlan.name}-scale'
  location: appServicePlanLocation
  properties: {
    profiles: [
      {
        name: 'Scale up condition'
        capacity: {
          maximum: '3'
          default: '1'
          minimum: '1'
        }
        rules: [
          {
            scaleAction: {
              type: 'ChangeCount'
              direction: 'Increase'
              cooldown: 'PT5M'
              value: '1'
            }
            metricTrigger: {
              metricName: 'CpuPercentage'
              operator: 'GreaterThan'
              timeAggregation: 'Average'
              threshold: 70
              metricResourceUri: appServicePlan.id
              timeWindow: 'PT10M'
              timeGrain: 'PT1M'
              statistic: 'Average'
            }
          }
          {
            scaleAction: {
              type: 'ChangeCount'
              direction: 'Decrease'
              cooldown: 'PT5M'
              value: '1'
            }
            metricTrigger: {
              metricName: 'CpuPercentage'
              operator: 'LessThan'
              timeAggregation: 'Average'
              threshold: 45
              metricResourceUri: appServicePlan.id
              timeWindow: 'PT10M'
              timeGrain: 'PT1M'
              statistic: 'Average'
            }
          }
        ]
      }
    ]
    enabled: true
    targetResourceUri: appServicePlan.id
  }
}
