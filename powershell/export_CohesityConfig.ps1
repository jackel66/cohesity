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
    [CmdletBinding()]
    param (
        [string]$clusterVip,
        [string]$targetPath,
        [string]$username,
        [string]$domain
    )

    try {
        apiauth -vip $clusterVip -Username $username -Domain $domain

        $clusterInfo = api get /public/cluster
        $clusterName = $clusterInfo.name -replace '[^a-zA-Z0-9_-]', '_'

        $date = Get-Date -Format "yyyy-MM-dd"
        $zipBaseName = "$clusterName-configs-$date.zip"
        $zipPath = Join-Path $targetPath $zipBaseName

        $exportItems = @{
            protectionJobs   = "/public/protectionJobs"
            protectionSources= "/public/protectionSources"
            protectionPolicies= "/public/protectionPolicies"
            users           = "/public/users"
            roles           = "/public/roles"
            groups          = "/public/groups"
            routes          = "/public/routes"
            nodes           = "cluster/nodes -v2"
            gflags          = "/nexus/clustr/list_gflags"
            security        = "security-config -v2"
            views           = "/public/views"
            clusterSummary  = "/public/cluster"
        }

        $jsonFiles = @()
        foreach ($item in $exportItems.GetEnumerator()) {
            $apiPath = $item.Value
            $data = api get $apiPath
            $jsonFile = Join-Path $targetPath "$clusterName-$($item.Key).json"
            Write-JsonFile -Path $jsonFile -Object $data
            $jsonFiles += $jsonFile
        }

        Compress-Archive -Path $jsonFiles -DestinationPath $zipPath -Force
        Remove-Item $jsonFiles -Force

        Write-Verbose "Export complete for $clusterVip. Output: $zipPath"
    } catch {
        Write-Error "Failed to export config for $clusterVip: $_"
    }
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