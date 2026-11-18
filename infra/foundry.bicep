param location string
param tags object
param foundryName string
param projectName string
param deploymentName string
param modelName string
param modelVersion string
param deploymentSku string
param tpmThousands int
param instructorPrincipalId string

var openAiUserRoleId = '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd'

resource foundry 'Microsoft.CognitiveServices/accounts@2025-06-01' = {
  name: foundryName
  location: location
  tags: tags
  kind: 'AIServices'
  sku: {
    name: 'S0'
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    customSubDomainName: foundryName
    allowProjectManagement: true
    publicNetworkAccess: 'Enabled'
    // Only API Management (managed identity) and the instructor (Entra ID) call the model, so keys stay off.
    disableLocalAuth: true
  }
}

resource project 'Microsoft.CognitiveServices/accounts/projects@2025-06-01' = {
  parent: foundry
  name: projectName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {}
}

resource deployment 'Microsoft.CognitiveServices/accounts/deployments@2025-06-01' = {
  parent: foundry
  name: deploymentName
  dependsOn: [
    project
  ]
  sku: {
    name: deploymentSku
    capacity: tpmThousands
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: modelName
      version: modelVersion
    }
    raiPolicyName: 'Microsoft.DefaultV2'
  }
}

resource instructorAccess 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(instructorPrincipalId)) {
  name: guid(foundry.id, instructorPrincipalId, openAiUserRoleId)
  scope: foundry
  properties: {
    principalId: instructorPrincipalId
    principalType: 'User'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', openAiUserRoleId)
  }
}

output foundryName string = foundry.name
output deploymentName string = deployment.name
