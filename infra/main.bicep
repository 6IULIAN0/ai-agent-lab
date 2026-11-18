// Instructor-only infrastructure for the AI agent lab.
// Creates a dedicated resource group with a Microsoft Foundry resource, a project,
// one capped model deployment, an API Management gateway that students call with a
// simple class key, and a cost budget with email alerts.
targetScope = 'subscription'

@description('Name of the new, dedicated resource group.')
param resourceGroupName string = 'rg-agent-lab-lecture'

@description('Azure region for all resources.')
param location string = 'swedencentral'

@description('Name of the Foundry (AI Services) resource. Also used as the endpoint subdomain, so it must be globally unique.')
param foundryName string = 'agent-lab-${uniqueString(subscription().id, resourceGroupName)}'

@description('Name of the Foundry project.')
param projectName string = 'agent-lab'

@description('Deployment name that the notebook uses as MODEL.')
param deploymentName string = 'agent-lab-model'

@description('Model to deploy.')
param modelName string

@description('Model version to deploy.')
param modelVersion string

@description('Deployment SKU.')
param deploymentSku string = 'GlobalStandard'

@description('Rate limit in thousands of tokens per minute. This is the cost brake.')
@minValue(1)
param tpmThousands int = 150

@description('Monthly cost budget for the resource group, in the billing currency.')
param budgetAmount int = 20

@description('Email address that receives budget alerts.')
param budgetEmail string

@description('First day of the budget period (yyyy-MM-01). Defaults to the current month.')
param budgetStartDate string = '${utcNow('yyyy-MM')}-01'

@description('Tags for all resources.')
param tags object = {
  purpose: 'ai-agent-lab'
}

@description('Optional Entra object ID of the instructor. Gets the Cognitive Services OpenAI User role, to use the Playground.')
param instructorPrincipalId string = ''

@description('Name of the API Management gateway. Must be globally unique.')
param apimName string = 'agent-lab-gw-${uniqueString(subscription().id, resourceGroupName)}'

@description('The simple key students paste into the notebook. Never commit it.')
@secure()
param classKey string

resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: resourceGroupName
  location: location
  tags: tags
}

module foundry 'foundry.bicep' = {
  name: 'agent-lab-foundry'
  scope: rg
  params: {
    location: location
    tags: tags
    foundryName: foundryName
    projectName: projectName
    deploymentName: deploymentName
    modelName: modelName
    modelVersion: modelVersion
    deploymentSku: deploymentSku
    tpmThousands: tpmThousands
    instructorPrincipalId: instructorPrincipalId
  }
}

module gateway 'apim.bicep' = {
  name: 'agent-lab-gateway'
  scope: rg
  params: {
    location: location
    tags: tags
    apimName: apimName
    publisherEmail: budgetEmail
    foundryName: foundry.outputs.foundryName
    classKey: classKey
  }
}

module budget 'budget.bicep' = {
  name: 'agent-lab-budget'
  scope: rg
  params: {
    amount: budgetAmount
    emails: [
      budgetEmail
    ]
    startDate: budgetStartDate
  }
}

output resourceGroupName string = rg.name
output foundryName string = foundry.outputs.foundryName
output apimName string = gateway.outputs.apimName
output endpoint string = gateway.outputs.gatewayUrl
output deploymentName string = foundry.outputs.deploymentName
