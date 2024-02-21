param registryName string
param registryLocation string
param registrySku string

@description('Tags.')
param tags object = {}

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2021-09-01' = {
  name: registryName
  tags: tags
  location: registryLocation
  sku: {
    name: registrySku
  }
  properties: {
    adminUserEnabled: true
  }
  identity: {
    type: 'SystemAssigned'
  }
}
