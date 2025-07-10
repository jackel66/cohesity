<#
.SYNOPSIS
Exports roles, routes, or accounts from a Cohesity cluster.

.DESCRIPTION
This script allows the user to export roles, static routes, and/or user/group accounts from a Cohesity cluster using the public API.

.PARAMETER vip
Cluster VIP or FQDN.

.PARAMETER user
Cohesity username.

.PARAMETER domain
Cohesity authentication domain.

.PARAMETER export
Type of export: roles, routes, accounts, or all.

.EXAMPLE
.\export_cohesity_data.ps1 -vip cohesity.domain.com -user user01 -domain domain.com -export all
.\export_cohesity_data.ps1 -vip cohesity.domain.com -user user01 -domain domain.com -export roles
.\export_cohesity_data.ps1 -vip cohesity.domain.com -user user01 -domain domain.com -export routes
.\export_cohesity_data.ps1 -vip cohesity.domain.com -user user01 -domain domain.com -export accounts
.\export_cohesity_data.ps1 -vip cohesity.domain.com -user user01 -domain domain.com -export accounts -accountType local

.NOTES
Author: Doug Austin
Date: 05/12/2025
Changelog:
    - Initial script Creation - 05/19/2025
#>

param (
    [Parameter(Mandatory = $false)]
    [string]$vip,

    [Parameter(Mandatory = $false)]
    [string]$user,

    [Parameter(Mandatory = $false)]
    [string]$domain = "cguser.capgroup.com", 

    [Parameter(Mandatory = $false)]
    [ValidateSet("roles", "routes", "accounts", "all")]
    [string]$export,
    
    [Parameter(Mandatory = $false)]
    [ValidateSet("domain", "local")]
    [string]$accountType = "domain",

    [switch]$help
)

# Help output
if ($help -or (-not $export)) {
    Write-Host @"
USAGE:
  .\export_cohesity_data.ps1 -vip <ClusterVIP> -user <Username> -domain <Domain> -export <roles|routes|accounts|all>

EXAMPLES:
  .\export_cohesity_data.ps1 -vip cohesity.domain.com -user user01 -domain domain.com -export <roles|routes|accounts|all>
  .\export_cohesity_data.ps1 -export all   # Prompts for missing values

DESCRIPTION:
  Exports roles, static routes, and/or domain users & groups from the specified Cohesity cluster.

NOTES:
  - LOCAL users and groups are automatically excluded from account export.
  - Outputs are saved to JSON files named <VIP>.<type>_export.json.

AUTHOR: Doug Austin
DATE: 05/12/2025
"@
    exit
}

# Prompt for any missing parameters
if (-not $vip) { $vip = Read-Host "Enter Cohesity VIP or cluster FQDN" }
if (-not $user) { $user = Read-Host "Enter username" }
if (-not $domain) { $domain = Read-Host "Enter domain" }

# Load Cohesity API Helper
. "$PSScriptRoot\cohesity-api.ps1"

# Authenticate
apiauth -vip $vip -username $user -domain $domain

# Export Roles
if ($export -eq "roles" -or $export -eq "all") {
    $roles = api get /public/roles
    $roles | ConvertTo-Json -Depth 10 | Out-File -FilePath "$($vip).roles_export.json" -Encoding utf8
    Write-Host "✅ Exported $($roles.Count) roles to $($vip).roles_export.json"
}

# Export Routes
if ($export -eq "routes" -or $export -eq "all") {
    $routes = api get /public/routes
    $routes | ConvertTo-Json -Depth 10 | Out-File -FilePath "$($vip).static_routes_export.json" -Encoding utf8
    Write-Host "✅ Exported $($routes.Count) routes to $($vip).static_routes_export.json"
}

# Export Accounts
if ($export -eq "accounts" -or $export -eq "all") {
    $allUsers = api get /public/users
    $allGroups = api get /public/groups

    if ($accountType -eq "local") {
        $exportUsers = $allUsers | Where-Object { $_.domain -eq "LOCAL" }
        $exportGroups = $allGroups | Where-Object { $_.domain -eq "LOCAL" }
    } else {
        $exportUsers = $allUsers | Where-Object { $_.domain -ne "LOCAL" }
        $exportGroups = $allGroups | Where-Object { $_.domain -ne "LOCAL" }
    }

    $exportData = @{
        users  = $exportUsers
        groups = $exportGroups
    }

    $suffix = if ($accountType -eq "local") { "local_accounts" } else { "account" }
    $exportFile = "$($vip).${suffix}_export.json"

    $exportData | ConvertTo-Json -Depth 10 | Out-File -FilePath $exportFile -Encoding utf8
    Write-Host "✅ Exported $($exportUsers.Count) users and $($exportGroups.Count) groups to $exportFile"
}
