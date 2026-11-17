#!/usr/bin/env pwsh
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
#Requires -Version 7.0

<#
.SYNOPSIS
    Deploys the AI agent lab infrastructure (instructor only).
.DESCRIPTION
    Creates a dedicated resource group with a Microsoft Foundry resource, a project,
    a model deployment capped by a tokens-per-minute limit, and a cost budget with
    email alerts. Shows a what-if preview first, then deploys, then prints the
    endpoint and deployment name for the notebook. The key is printed to the console
    only when -ShowKey is set, and is never written to disk.
.PARAMETER SubscriptionId
    Azure subscription to deploy into.
.PARAMETER Location
    Azure region.
.PARAMETER ResourceGroupName
    Name of the new, dedicated resource group.
.PARAMETER ModelName
    Model to deploy.
.PARAMETER ModelVersion
    Model version to deploy.
.PARAMETER TpmThousands
    Rate limit in thousands of tokens per minute.
.PARAMETER BudgetAmount
    Monthly budget for the resource group (alerts only).
.PARAMETER BudgetEmail
    Email address that receives budget alerts.
.PARAMETER Tags
    Tags for all resources. Add any tag your tenant requires, for example a
    policy-exemption tag that allows key authentication.
.PARAMETER ShowKey
    Print Key 1 to the console after deployment.
.PARAMETER Force
    Skip the confirmation prompt after the what-if preview.
.EXAMPLE
    ./infra/deploy.ps1 -SubscriptionId <id> -BudgetEmail you@example.com -ShowKey
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$SubscriptionId,

    [Parameter(Mandatory = $false)]
    [string]$Location = 'swedencentral',

    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName = 'rg-agent-lab-lecture',

    [Parameter(Mandatory = $false)]
    [string]$ModelName = 'gpt-6-luna',

    [Parameter(Mandatory = $false)]
    [string]$ModelVersion = '2026-09-22',

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 1000)]
    [int]$TpmThousands = 150,

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 100000)]
    [int]$BudgetAmount = 20,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$BudgetEmail,

    # SecurityControl=Ignore exempts the resource from the MCAPSGov policy that disables key authentication.
    # SecurityPolicy=Ignore is the tenant's general exemption tag.
    [Parameter(Mandatory = $false)]
    [hashtable]$Tags = @{ purpose = 'ai-agent-lab'; SecurityControl = 'Ignore'; SecurityPolicy = 'Ignore' },

    [Parameter(Mandatory = $false)]
    [switch]$ShowKey,

    [Parameter(Mandatory = $false)]
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

#region Main Execution

if ($MyInvocation.InvocationName -ne '.') {
    try {
        $Template = Join-Path $PSScriptRoot 'main.bicep'
        $DeploymentName = "agent-lab-$(Get-Date -Format 'yyyyMMddHHmmss')"
        $ParametersFile = Join-Path ([IO.Path]::GetTempPath()) "$DeploymentName.parameters.json"

        az account set --subscription $SubscriptionId
        if ($LASTEXITCODE -ne 0) { throw 'Could not select the subscription. Run az login first.' }

        $InstructorId = az ad signed-in-user show --query id -o tsv 2>$null
        $Values = [ordered]@{
            resourceGroupName     = $ResourceGroupName
            location              = $Location
            modelName             = $ModelName
            modelVersion          = $ModelVersion
            tpmThousands          = $TpmThousands
            budgetAmount          = $BudgetAmount
            budgetEmail           = $BudgetEmail
            tags                  = $Tags
            instructorPrincipalId = [string]$InstructorId
        }
        $ParameterObject = [ordered]@{
            '$schema'      = 'https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#'
            contentVersion = '1.0.0.0'
            parameters     = [ordered]@{}
        }
        foreach ($Name in $Values.Keys) { $ParameterObject.parameters[$Name] = @{ value = $Values[$Name] } }
        $ParameterObject | ConvertTo-Json -Depth 10 | Set-Content -Path $ParametersFile -Encoding UTF8

        Write-Host '🔎 What-if preview' -ForegroundColor Cyan
        az deployment sub what-if --location $Location --template-file $Template --parameters "@$ParametersFile" --only-show-errors
        if ($LASTEXITCODE -ne 0) { throw 'What-if failed.' }

        if (-not $Force) {
            $Answer = Read-Host 'Deploy these changes? (y/N)'
            if ($Answer -notin @('y', 'Y', 'yes')) {
                Write-Host 'Cancelled.' -ForegroundColor Yellow
                exit 0
            }
        }

        Write-Host '🚀 Deploying (this takes a few minutes)' -ForegroundColor Cyan
        $Outputs = az deployment sub create --name $DeploymentName --location $Location --template-file $Template `
            --parameters "@$ParametersFile" --query properties.outputs --only-show-errors -o json | ConvertFrom-Json
        if ($LASTEXITCODE -ne 0) { throw 'Deployment failed.' }

        $FoundryName = $Outputs.foundryName.value
        Write-Host ''
        Write-Host '✅ Deployed. Paste these into the first code cell of agent_lab.ipynb:' -ForegroundColor Green
        Write-Host "   ENDPOINT = `"$($Outputs.endpoint.value)`""
        Write-Host "   MODEL = `"$($Outputs.deploymentName.value)`""
        Write-Host ''
        Write-Host "   Resource group: $ResourceGroupName   Foundry resource: $FoundryName"

        # A tenant policy can switch key authentication off after deployment.
        $LocalAuthDisabled = az cognitiveservices account show -g $ResourceGroupName -n $FoundryName --query properties.disableLocalAuth -o tsv
        if ($LocalAuthDisabled -eq 'true') {
            Write-Host '⚠️  Key authentication is disabled on the resource, probably by a tenant policy.' -ForegroundColor Yellow
            Write-Host '   Students cannot connect with a key. Add the exemption tag with -Tags and run this script again.' -ForegroundColor Yellow
        }
        elseif ($ShowKey) {
            $Key = az cognitiveservices account keys list -g $ResourceGroupName -n $FoundryName --query key1 -o tsv
            Write-Host "   Key 1 (never commit it): $Key" -ForegroundColor Yellow
        }
        exit 0
    }
    catch {
        Write-Error -ErrorAction Continue "deploy.ps1 failed: $($_.Exception.Message)"
        exit 1
    }
    finally {
        if ($ParametersFile -and (Test-Path $ParametersFile)) { Remove-Item $ParametersFile -Force }
    }
}

#endregion Main Execution
