#!/usr/bin/env pwsh
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
#Requires -Version 7.0

<#
.SYNOPSIS
    Run straight after the lesson: invalidates the class key, optionally deletes everything.
.DESCRIPTION
    Suspends the class key on the API Management gateway, so the key shown in class
    stops working immediately. Run deploy.ps1 again to reactivate it.
    With -DeleteResourceGroup, deletes the whole resource group instead.
.PARAMETER SubscriptionId
    Azure subscription that contains the lab.
.PARAMETER ResourceGroupName
    Resource group created by deploy.ps1.
.PARAMETER DeleteResourceGroup
    Delete the whole resource group (model, project, gateway, budget).
.EXAMPLE
    ./infra/cleanup.ps1 -SubscriptionId <id>
.EXAMPLE
    ./infra/cleanup.ps1 -SubscriptionId <id> -DeleteResourceGroup
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$SubscriptionId,

    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName = 'rg-agent-lab-lecture',

    [Parameter(Mandatory = $false)]
    [switch]$DeleteResourceGroup
)

$ErrorActionPreference = 'Stop'

#region Main Execution

if ($MyInvocation.InvocationName -ne '.') {
    try {
        az account set --subscription $SubscriptionId
        if ($LASTEXITCODE -ne 0) { throw 'Could not select the subscription. Run az login first.' }

        if ($DeleteResourceGroup) {
            $Answer = Read-Host "Delete resource group '$ResourceGroupName' and everything in it? (y/N)"
            if ($Answer -notin @('y', 'Y', 'yes')) {
                Write-Host 'Cancelled.' -ForegroundColor Yellow
                exit 0
            }
            az group delete --name $ResourceGroupName --yes --no-wait
            if ($LASTEXITCODE -ne 0) { throw 'Delete failed.' }
            Write-Host "🗑️  Deleting $ResourceGroupName in the background." -ForegroundColor Green
            exit 0
        }

        $ApimName = az resource list -g $ResourceGroupName --resource-type Microsoft.ApiManagement/service --query '[0].name' -o tsv
        if (-not $ApimName) { throw "No API Management gateway found in $ResourceGroupName." }

        $SubscriptionUrl = "https://management.azure.com/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName" +
            "/providers/Microsoft.ApiManagement/service/$ApimName/subscriptions/class?api-version=2024-05-01"
        $BodyFile = Join-Path ([IO.Path]::GetTempPath()) 'agent-lab-suspend.json'
        '{"properties":{"state":"suspended"}}' | Set-Content -Path $BodyFile -Encoding ascii
        az rest --method patch --url $SubscriptionUrl --headers 'If-Match=*' --body "@$BodyFile" -o none
        $RestExitCode = $LASTEXITCODE
        Remove-Item $BodyFile -Force
        if ($RestExitCode -ne 0) { throw 'Could not suspend the class key.' }
        Write-Host "🔑 Class key suspended on $ApimName. It no longer works. Run deploy.ps1 to reactivate it." -ForegroundColor Green
        exit 0
    }
    catch {
        Write-Error -ErrorAction Continue "cleanup.ps1 failed: $($_.Exception.Message)"
        exit 1
    }
}

#endregion Main Execution
