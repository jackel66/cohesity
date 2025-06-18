<#
.SYNOPSIS
Exports configuration data from a Cohesity cluster.

.DESCRIPTION
This script exports configuration data from a Cohesity cluster, including protection jobs, sources, policies, users, roles, groups, custom routes, and nodes. It creates JSON files for each type of data and compresses them into a zip file. The script can handle multiple clusters specified in a text file or a single cluster directly.

.PARAMETER source (Required)
Cluster Source, either a VIP address or a path to a text file containing multiple VIP addresses.

.PARAMETER username (Required)
Cohesity username

.PARAMETER domain (Optional)
Cohesity authentication domain.

.PARAMETER targetPath (Optional)
(Optional) The target location for the exports Default is Local Directory


.NOTES
Author: Doug Austin
Date: 05/12/2025
Changelog:
    - Initial script Creation - 05/19/2025
    - Added support for multiple clusters from a text file - 05/20/2025
    - Added support for custom routes and nodes - 05/21/2025
    - Added security config export - 05/22/2025
    - Added views export - 05/23/2025
    - Added gflags export - 05/24/2025
    - Added cluster summary export - 05/25/2025
    - Added error handling for existing zip files - 05/26/2025
    - Added cleanup of old zip files older than 30 days - 05/27/2025
    - Added JSON file creation for each export - 05/28/2025
    - Added support for custom domain in authentication - 05/29/2025
    - Added handling for empty or null objects in JSON export - 05/30/2025
    - Added sanitization for cluster names in file names - 05/31/2025
    - Added depth parameter for JSON conversion - 06/01/2025
    - Added support for multiple clusters in a single run - 06/02/2025
#>


param ( 
    [Parameter(Mandatory)]
    [string]$source,
    [string]$targetPath = ".",
    [Parameter(Mandatory)]
    [string]$username,
    [string]$domain = 'domain.com'
)

# --- Load Cohesity API functions ---
. "$PSScriptRoot\cohesity-api.ps1"

# --- Function to write JSON data to a file ---
function Write-JsonFile {
    param (
        [Parameter(Mandatory)]
        [string]$Path, 
        $Object,
        [int]$Depth = 10
    )
    if ($null -eq $Object) {
        if ($Path -like '*Summary*') {
            '{}' | Set-Content $Path -Encoding UTF8
        } else {
            '[]' | Set-Content $Path -Encoding UTF8
        }
    } else {
        $Object | ConvertTo-Json -Depth $Depth | Set-Content $Path -Encoding UTF8
    }
}

# --- Function to export Cohesity configuration data ---
function Export-CohesityConfig {
    param (
        [string]$clusterVip,
        [string]$targetPath,
        [string]$username,
        [string]$domain
    )

    # --- Authenticate to Cohesity cluster --- 
    apiauth -vip $clusterVip -Username $username -Domain $domain

    # --- Get cluster name and summary ---
    $clusterInfo = api get /public/cluster
    $clusterName = $clusterInfo.name -replace '[^a-zA-Z0-9_-]', '_' # Sanitize for file name

    # --- Remove zip files older than 30 days in the target directory for this cluster ---
    $zipPattern = "$clusterName-configs-*.zip"
    Get-ChildItem -Path $targetPath -Filter $zipPattern | Where-Object {
        $_.LastWriteTime -lt (Get-Date).AddDays(-30)
    } | ForEach-Object {
        Write-Host "Removing old backup: $($_.FullName)"
        Remove-Item $_.FullName
    }
    # --- Initialize variables for API calls ---
    if ($null -eq $protectionJobs -or $protectionJobs.Count -eq 0) { $protectionJobs = @() }
    if ($null -eq $sources -or $sources.Count -eq 0) { $sources = @() }
    if ($null -eq $protectionPolicies  -or $protectionPolicies.Count -eq 0) { $protectionPolicies = @() }
    if ($null -eq $users) { $users = @() }
    if ($null -eq $roles) { $roles = @() }
    if ($null -eq $groups) { $groups = @() }
    if ($null -eq $route) { $route = @() }
    if ($null -eq $nodes) { $nodes = @() }
    if ($null -eq $gflags) { $gflags = @() }
    if ($null -eq $views) { $views = @() }
    if ($null -eq $security) { $security = @() }
    if ($null -eq $clusterInfo) { $clusterInfo = @{} }

    # --- Get protection jobs, sources, and policies ---
    $protectionJobs = api get /public/protectionJobs
    $sources = api get /public/protectionSources
    $protectionPolicies = api get /public/protectionPolicies
    $users = api get /public/users
    $roles = api get /public/roles
    $groups = api get /public/groups
    $route = api get /public/routes
    $nodes = api get cluster/nodes -v2
    $gflags = (api get /nexus/clustr/list_gflags).serviceGflags
    $security = api get security-config -v2
    $views = api get /public/views
    
    # --- Prepare output directory and filenames ---
    $date = Get-Date -Format "yyyy-MM-dd"
    $zipBaseName = "$clusterName-configs-$date.zip"
    $zipPath = Join-Path $targetPath $zipBaseName

    $jobsJson = Join-Path $targetPath "$clusterName-protectionJobs.json"
    $sourcesJson = Join-Path $targetPath "$clusterName-protectionSources.json"
    $policiesJson = Join-Path $targetPath "$clusterName-protectionPolicies.json"
    $usersJson = Join-Path $targetPath "$clusterName-users.json"
    $rolesJson = Join-Path $targetPath "$clusterName-roles.json"
    $clusterSummaryJson = Join-Path $targetPath "$clusterName-clusterSummary.json"
    $groupsJson = Join-Path $targetPath "$clustername-groups.json"
    $nodesJson = Join-Path $targetPath "$clusterName-nodes.json"
    $routeJson = Join-Path $targetPath "$clusterName-customRoutes.json"
    $gflagsJson = Join-Path $targetPath "$clustername-gflags.json"
    $securityJson = Join-Path $targetPath "$clusterName-security-config.json"
    $viewsJson = Join-Path $targetPath "$clusterName-views.json"

    # --- Handle existing zip file ---
    $counter = 1
    while (Test-Path $zipPath) {
        $choice = Read-Host "File '$zipBaseName' already exists. Overwrite (Y) or create new with (N)? [Y/N]"
        if ($choice -eq "Y" -or $choice -eq "y") {
            Remove-Item $zipPath
            break
        } else {
            $zipBaseName = "$clusterName-configs-$date($counter).zip"
            $zipPath = Join-Path $targetPath $zipBaseName
            $counter++
        }
    }

# --- Export data to JSON files ---
    Write-JsonFile -Path $jobsJson -Object $protectionJobs
    Write-JsonFile -Path $sourcesJson -Object $sources
    Write-JsonFile -Path $policiesJson -Object $protectionPolicies
    Write-JsonFile -Path $usersJson -Object $users
    Write-JsonFile -Path $rolesJson -Object $roles
    Write-JsonFile -Path $groupsJson -Object $groups
    Write-JsonFile -Path $routeJson -Object $route
    Write-JsonFile -Path $nodesJson -Object $nodes
    Write-JsonFile -Path $clusterSummaryJson -Object $clusterInfo
    Write-JsonFile -Path $gflagsJson -Object $gflags
    Write-JsonFile -Path $securityJson -Object $security
    Write-JsonFile -Path $viewsJson -Object $views
 

    # --- Zip the JSON files ---
    Compress-Archive -Path $jobsJson, $sourcesJson, $policiesJson, $usersJson, $rolesJson, $groupsJson, $routeJson, $nodesJson, $clusterSummaryJson, $securityJson, $viewsJson, $gflagsJson -DestinationPath $zipPath

    # --- Clean up JSON files ---
    Remove-Item $jobsJson, $sourcesJson, $policiesJson, $usersJson, $rolesJson, $groupsJson, $routeJson, $nodesJson, $clusterSummaryJson, $securityJson, $viewsJson, $gflagsJson

    Write-Host "Export complete for $clusterVip. Output: $zipPath"
}

# --- Main logic: handle single cluster or file with multiple clusters --- 
if (Test-Path $source -PathType Leaf) {
    $clusterList = Get-Content $source | Where-Object { $_.Trim() -ne "" }
    foreach ($clusterVip in $clusterList) {
        $serverTargetPath = Join-Path -Path $targetPath -ChildPath $clusterVip
        if (-not (Test-path $serverTargetPath)) {
            New-Item -ItemType Directory -Path $serverTargetPath | Out-Null
        }
        Export-CohesityConfig -clusterVip $clusterVip -targetPath $serverTargetPath -username $username -domain $domain
    }
} else {
    $serverTargetPath = Join-Path -Path $targetPath -ChildPath $source
    if (-not (Test-Path $serverTargetPath)) {
        New-Item -ItemType Directory -Path $serverTargetPath | Out-Null
    }
    Export-CohesityConfig -clusterVip $source -targetPath $serverTargetPath -username $username -domain $domain
}