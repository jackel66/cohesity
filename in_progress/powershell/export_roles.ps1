<#
.SYNOPSIS
Exports Cohesity custom roles from a specified cluster.

.DESCRIPTION
This script connects to a Cohesity cluster, authenticates with the provided credentials, and exports all roles to a JSON file.

.PARAMETER vip
The FQDN or IP address of the Cohesity cluster.

.PARAMETER user
The username for Cohesity authentication.

.PARAMETER domain
The domain for the user account (e.g., LOCAL or AD domain).

.EXAMPLE
.\export_roles.ps1 -vip cohesity.domain.com -user user01 -domain domain.com

.NOTES
Author: Douglas Austin  
Date: 05/12/2025  
Changelog:
  - Initial build: 05/12/2025
  - Added dynamic VIP, Username, Domain prompts: 05/19/2025
  - Added help section to provide details on how to execute: 05/19/2025
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
  .\export_roles.ps1 -vip <ClusterVIP> -user <Username> -domain <Domain>

EXAMPLE:
  .\export_roles.ps1 -vip cohesity.domain.com -user user01 -domain domain.com

DESCRIPTION:
  Exports Cohesity user roles from the given cluster to a JSON file.
  If any parameter is missing, the script will prompt for it.

NOTES:
  - The script will prompt for a password during authentication.
  - The output file will be named <VIP>.roles_export.json.

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

# Authenticate (will prompt for password automatically)
apiauth -vip $vip -username $user -domain $domain

# Export Roles
$roles = api get /public/roles

# Check for roles export success
if ($roles) {
    # Save JSON
    $exportFile = "$($vip).roles_export.json"
    $roles | ConvertTo-Json -Depth 10 | Out-File -FilePath $exportFile -Encoding utf8
