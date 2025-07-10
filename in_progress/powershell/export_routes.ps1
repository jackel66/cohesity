<#
.SYNOPSIS
Exports Cohesity static routes from a specified cluster.

.DESCRIPTION
Connects to a Cohesity cluster and exports static routes from /public/routes into a JSON file.

.PARAMETER vip
The FQDN or IP address of the Cohesity cluster.

.PARAMETER user
The username for Cohesity authentication.

.PARAMETER domain
The domain for the user account (e.g., LOCAL or AD domain).

.EXAMPLE
.\export_roles.ps1 -vip cohesity.domain.com -user user01 -domain domain.com

.NOTES
Author: Doug Austin  
Date: 05/12/2025  
Changelog:
  - Initial version with static VIP/username/domain
  - Updated for dynamic input and help
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
  .\export_routes.ps1 -vip <ClusterVIP> -user <Username> -domain <Domain>

EXAMPLE:
  .\export_roles.ps1 -vip cohesity.domain.com -user user01 -domain domain.com

DESCRIPTION:
  Exports Cohesity static routes from the given cluster to a JSON file.
  If any parameter is missing, the script will prompt for it.

NOTES:
  - The script will prompt for a password during authentication.
  - The output file will be named <VIP>.static_routes_export.json.

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

# Export Routes
$routes = api get /public/routes

# Save JSON
$exportFile = "$($vip).static_routes_export.json"
$routes | ConvertTo-Json -Depth 10 | Out-File -FilePath $exportFile -Encoding utf8

Write-Host "✅ Exported $($routes.Count) static routes to $exportFile"
