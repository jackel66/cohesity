<#
.SYNOPSIS
Exports Cohesity user and group accounts (non-LOCAL) from a cluster.

.DESCRIPTION
Connects to a Cohesity cluster and exports all AD/SSO users and groups (excluding LOCAL) into a JSON file.

.PARAMETER vip
The FQDN or IP address of the Cohesity cluster.

.PARAMETER user
The username for Cohesity authentication.

.PARAMETER domain
The domain of the user account (e.g., LOCAL or AD domain).

.EXAMPLE
.\export_roles.ps1 -vip cohesity.domain.com -user user01 -domain domain.com

.NOTES
Author: Doug Austin  
Date: 05/12/2025  
Changelog:
  - Initial version for exporting accounts
  - Refactored for dynamic input and help
#>

param (
    [Parameter(Mandatory = $false)]
    [string]$vip,

    [Parameter(Mandatory = $false)]
    [string]$user,

    [Parameter(Mandatory = $false)]
    [string]$domain,

    [switch]$help
)

# Help output
if ($help) {
    Write-Host @"
USAGE:
  .\export_accounts.ps1 -vip <ClusterVIP> -user <Username> -domain <Domain>

EXAMPLE:
  .\export_roles.ps1 -vip cohesity.domain.com -user user01 -domain domain.com

DESCRIPTION:
  Exports all Cohesity users and groups EXCEPT those using the LOCAL domain.
  Outputs to <VIP>.account_export.json.

NOTES:
  - The script will prompt for a password during authentication.
  - LOCAL users and groups are excluded.

AUTHOR: Doug Austin
DATE: 05/12/2025
"@
    exit
}

# Prompt for missing parameters
if (-not $vip) {
    $vip = Read-Host "Enter Cohesity VIP or cluster FQDN"
}
if (-not $user) {
    $user = Read-Host "Enter username"
}
if (-not $domain) {
    $domain = Read-Host "Enter domain"
}

# Load Cohesity API Helper
. "$PSScriptRoot\cohesity-api.ps1"

# Authenticate (prompts for password)
apiauth -vip $vip -username $user -domain $domain

# Export users and groups (excluding LOCAL)
$allUsers = api get /public/users
$exportUsers = $allUsers | Where-Object { $_.domain -ne "LOCAL" }

$allGroups = api get /public/groups
$exportGroups = $allGroups | Where-Object { $_.domain -ne "LOCAL" }

# Save both to JSON
$export = @{
    users  = $exportUsers
    groups = $exportGroups
}
$exportFile = "$($vip).account_export.json"
$export | ConvertTo-Json -Depth 10 | Out-File -FilePath $exportFile -Encoding utf8

Write-Host "✅ Exported $($exportUsers.Count) users and $($exportGroups.Count) groups to $exportFile"
