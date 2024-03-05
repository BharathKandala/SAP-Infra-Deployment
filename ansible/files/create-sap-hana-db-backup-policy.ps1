#!/usr/bin/env pwsh
param (
    [Parameter(Mandatory = $false)]
    [string]$vaultResourceGroupName,
    [Parameter(Mandatory = $false)]
    [string]$vaultName,
    [Parameter(Mandatory = $false)]
    [string]$backupPolicyFile,
    [Parameter(Mandatory = $false)]
    [string]$backupPolicyName
)

#Create backup policy
Write-Host "[##debug Create or update SAP Hana DB backup policy.]"
$result = az backup policy create `
    --resource-group $vaultResourceGroupName `
    --vault-name $vaultName `
    --name $backupPolicyName `
    --backup-management-type AzureWorkload `
    --policy $backupPolicyFile `
    --workload-type SAPHana
$result