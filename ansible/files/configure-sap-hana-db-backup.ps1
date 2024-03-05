#!/usr/bin/env pwsh
param (
  [Parameter(Mandatory = $false)]
  [string]$backupPolicyName,
  [Parameter(Mandatory = $false)]
  [string]$vaultResourceGroupName,
  [Parameter(Mandatory = $false)]
  [string]$vaultName,
  [Parameter(Mandatory = $false)]
  [string]$sapHanaDbServerHostname,
  [Parameter(Mandatory = $false)]
  [string]$sapHanaDbVmName,
  [Parameter(Mandatory = $false)]
  [string]$sapHanaDbVmResourceGroupName,
  [Parameter(Mandatory = $false)]
  [string]$sapHanaDbServerName,
  [Parameter(Mandatory = $false)]
  $sapHanaDbList
)

# Split the list of databases into an array
$sapHanaDbList = $sapHanaDbList.split(",")
Write-Host "List of databases: $sapHanaDbList"

$vmId = az vm show --resource-group $sapHanaDbVmResourceGroupName --name $sapHanaDbVmName --query id -o tsv

Write-Host "Registering VM $sapHanaDbVmName to Recovery Services Vault $vaultName"
az backup container register `
  --resource-group $vaultResourceGroupName `
  --resource-id $vmId `
  --vault-name $vaultName `
  --workload-type SAPHANA `
  --backup-management-type AzureWorkload

# When a VM is re-created with the same name, re-registration is mandatory
Write-Host "[##debug] Re-registering VM $sapHanaDbVmName to Recovery Services Vault $vaultName"
az backup container re-register `
  --resource-group $vaultResourceGroupName `
  --vault-name $vaultName `
  --container-name "VMAppContainer;Compute;$sapHanaDbVmResourceGroupName;$sapHanaDbVmName" `
  --workload-type SAPHANA `
  --yes

# Check if backup registration is successful
$registrationStatus = az backup container list `
  --resource-group $vaultResourceGroupName `
  --vault-name $vaultName `
  --backup-management-type AzureWorkload | ConvertFrom-Json

foreach ($registeredHost in $registrationStatus) { 
  Write-Host $registeredHost.properties.extendedInfo.hostServerName
  if (($registeredHost.properties.extendedInfo.hostServerName -eq $sapHanaDbServerName) -and 
  ($registeredHost.properties.registrationStatus -eq "Registered")) {
    $registeredHostExists =  $True
  }
} 

if ($registeredHostExists) {
  Write-Host "[##debug] Registration check succeeded!"
}
else {
  Write-Error "##vso[task.logissue type=error] Registration check for server $($registrationStatus.properties.extendedInfo.hostServerName) (expected $($sapHanaDbServerName)) failed! Make sure the SAP Hana DB VM is discovered by Azure Recovery Services Vault $vaultName."
  exit 1
}

Write-Host "[##debug] Terraform will create the backup for $sapHanaDbServerName"
Write-Host "[##debug] List of SAP Hana DBs to backup: $sapHanaDbList"
Write-Host "[##debug] Looping over list: $sapHanaDbList"

foreach ($db in $sapHanaDbList) {
  Write-Host "[##debug] Processing item: $db"
  $result = az backup protection enable-for-azurewl `
  --resource-group $vaultResourceGroupName `
  --vault-name $vaultName `
  --policy-name $backupPolicyName `
  --protectable-item-name $db `
  --protectable-item-type SAPHANADatabase `
  --server-name $sapHanaDbServerName `
  --workload-type SAPHANA
  $result
}