<#
.SYNOPSIS
Deletes Cohesity protection groups based on IDs from a text file.

.DESCRIPTION
This script deletes Cohesity protection groups using their IDs specified in a text file.

.PARAMETER vip
The VIP address of the Cohesity cluster.

.PARAMETER username
The username for Cohesity API authentication.

.PARAMETER domain
The domain for Cohesity API authentication (default is 'LOCAL').

.PARAMETER idFile
The path to the text file containing the protection group IDs for deletion. (default is "ids.txt" in the script directory).

.EXAMPLE
.\delProtectionGroups.ps1 -vip "<VIP_ADDRESS>" -username "<USERNAME>" -domain "<DOMAIN>" -idFile "<ID_FILE_PATH>"

.NOTES
Ensure that the Cohesity API PowerShell module is available and that the script has the necessary permissions to delete protection groups. (cohesity-api.ps1 should be in the same directory or properly referenced)


.Author
Doug Austin
Date: 2025-06-30
Change Log:
25-06-30: Initial version created by Doug Austin

#>

param (
    [string]$vip,
    [string]$username,
    [string]$domain = 'LOCAL',
    [string]$idFile = "$PSScriptRoot\ids.txt" # Path to the file with IDs
)

. "$PSScriptRoot\cohesity-api.ps1"

apiauth -vip $vip -username $username -domain $domain

# Read lines from the text file
$lines = Get-Content -Path $idFile

foreach ($line in $lines) {
    if ($line -match '^\s*(.*?)\s*:\s*(.*?)\s*$') {
        $name = $matches[1].Trim()
        $id = $matches[2].Trim()
        Write-Host "Deleting protection group '$name' with ID: $id (deleteSnapshots=False)"
        api delete -v1 "data-protect/protection-groups/$id?deleteSnapshots=false"
    } else {
        Write-Warning "Skipping invalid line: $line"
    }

    Write-Output "Action: Deleted protection group '$name' with ID: $id"
}