# Check the Status of Protected VMs
# Usage: getProtectionSources.ps1 -vip sjx1bkavcl-az.cguser.capgroup.com -username condoua2a -domain cguser.capgroup.com -unProtected
# Will generate a liste of Source vCenters, and execute a protected/unprotected look at them. It will dump the output in to /Reports/vmReport-type.csv

[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,  # the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username,  # username (local or AD)
    [Parameter()][string]$domain = 'local', # local or AD Domain
    [Parameter()][string]$parentSourceName,
    [Parameter()][Int64]$parentSourceId,
    [Parameter()][switch]$protected,
    [Parameter()][switch]$unProtected
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1) 

# authenticate
apiauth -vip $vip -username $username -domain $domain

# Get Source list
$registeredSources = api get "protectionSources?environments=kVMware"
$source = $registeredSources.protectionSource.name

# Check Protection Status API call
$report = api get /reports/objects/vmsProtectionStatus

# Report Output File Base name
$outFile = "vmReport"

#Create Output Folder if not present
$folderPath = Join-Path $PSScriptRoot "Reports"
if (!(Test-Path $folderPath)) {
    New-Item -ItemType Directory -Path $folderPath
}

if($parentSourceName){
    $report = $report | Where-Object registeredSourceName -eq $parentSourceName
    $outFile += "-$parentSourceName"
}elseif($parentSourceId){
    $report = $report | Where-Object registeredSourceId -eq $parentSourceId
    $outFile += "-$parentSourceId"
}

if($protected){
    $report = $report | Where-Object protected -eq $True
    $outFile += "-protected"
}elseif ($unprotected) {
    $report = $report | Where-Object protected -eq $false
    $outFile += "-unProtected"
}

$outFile = $(Join-Path -Path $PSScriptRoot -ChildPath "Reports/$outFile.csv")

$report | Format-Table
$report | Export-Csv -LiteralPath $outFile
write-host "Report saved as $outFile"