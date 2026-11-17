#!/usr/bin/env pwsh
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
#Requires -Version 7.0

<#
.SYNOPSIS
    Run straight after the lesson: invalidates the class key, optionally deletes everything.
.DESCRIPTION
    Regenerates Key 1 of the Foundry resource so the key shown in class stops working
    immediately. With -DeleteResourceGroup, deletes the whole resource group instead.
.PARAMETER SubscriptionId
    Azure subscription that contains the lab.
.PARAMETER ResourceGroupName
    Resource group created by deploy.ps1.
.PARAMETER DeleteResourceGroup
    Delete the whole resource group (model, project, budget).
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

        $FoundryName = az cognitiveservices account list -g $ResourceGroupName --query '[0].name' -o tsv
        if (-not $FoundryName) { throw "No Foundry resource found in $ResourceGroupName." }

        az cognitiveservices account keys regenerate -g $ResourceGroupName -n $FoundryName --key-name Key1 -o none
        if ($LASTEXITCODE -ne 0) { throw 'Key regeneration failed.' }
        Write-Host "🔑 Key 1 of $FoundryName regenerated. The class key no longer works." -ForegroundColor Green
        exit 0
    }
    catch {
        Write-Error -ErrorAction Continue "cleanup.ps1 failed: $($_.Exception.Message)"
        exit 1
    }
}

#endregion Main Execution
