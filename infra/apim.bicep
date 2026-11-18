// AI gateway: students call API Management with a simple class key.
// API Management calls Foundry with its managed identity, so Foundry needs no keys.
param location string
param tags object
param apimName string
param publisherEmail string
param foundryName string

@secure()
param classKey string

var openAiUserRoleId = '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd'

resource foundry 'Microsoft.CognitiveServices/accounts@2025-06-01' existing = {
  name: foundryName
}

resource apim 'Microsoft.ApiManagement/service@2024-05-01' = {
  name: apimName
  location: location
  tags: tags
  sku: {
    name: 'Consumption'
    capacity: 0
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    publisherEmail: publisherEmail
    publisherName: 'AI Agent Lab'
  }
}

resource apimToFoundry 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(foundry.id, apim.id, openAiUserRoleId)
  scope: foundry
  properties: {
    principalId: apim.identity.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', openAiUserRoleId)
  }
}

// The OpenAI SDK sends the key in the api-key header, so API Management reads the class key from there.
resource api 'Microsoft.ApiManagement/service/apis@2024-05-01' = {
  parent: apim
  name: 'foundry-openai'
  properties: {
    displayName: 'Foundry OpenAI'
    path: 'openai'
    protocols: [
      'https'
    ]
    serviceUrl: 'https://${foundry.properties.customSubDomainName}.openai.azure.com/openai'
    subscriptionRequired: true
    subscriptionKeyParameterNames: {
      header: 'api-key'
      query: 'subscription-key'
    }
  }
}

resource postAll 'Microsoft.ApiManagement/service/apis/operations@2024-05-01' = {
  parent: api
  name: 'post-all'
  properties: {
    displayName: 'POST all'
    method: 'POST'
    urlTemplate: '/*'
  }
}

resource getAll 'Microsoft.ApiManagement/service/apis/operations@2024-05-01' = {
  parent: api
  name: 'get-all'
  properties: {
    displayName: 'GET all'
    method: 'GET'
    urlTemplate: '/*'
  }
}

resource apiPolicy 'Microsoft.ApiManagement/service/apis/policies@2024-05-01' = {
  parent: api
  name: 'policy'
  properties: {
    format: 'rawxml'
    value: '''
<policies>
  <inbound>
    <base />
    <set-header name="api-key" exists-action="delete" />
    <authentication-managed-identity resource="https://cognitiveservices.azure.com" />
  </inbound>
  <backend>
    <base />
  </backend>
  <outbound>
    <base />
  </outbound>
  <on-error>
    <base />
  </on-error>
</policies>
'''
  }
}

resource classSubscription 'Microsoft.ApiManagement/service/subscriptions@2024-05-01' = {
  parent: apim
  name: 'class'
  properties: {
    displayName: 'Class key'
    scope: '/apis/${api.name}'
    primaryKey: classKey
    state: 'active'
    allowTracing: false
  }
}

output apimName string = apim.name
output gatewayUrl string = '${apim.properties.gatewayUrl}/'
