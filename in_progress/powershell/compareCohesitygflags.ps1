<#

.SYNOPSIS
    Compares the current Cohesity cluster gflags against a reference gflags file or another cluster.

.DESCRIPTION
    This script retrieves the current gflags from a Cohesity cluster and compares them against a reference gflags file or another cluster.
    It outputs any differences found between the two sets of gflags.

.PARAMETER SourceServer <Required>
    The VIP or FQDN of the Cohesity cluster.

.PARAMETER ReferenceFile <optional>
    The path to the reference gflags file in JSON format.

.PARAMETER ReferenceDir <optional>
    The path to the directory containing the cluster zip file.

.PARAMETER Username <Required>
    The Cohesity username for authentication.

.PARAMETER ExportOnly <optional>
    If set, the script will only export the current gflags without performing any comparison.

.PARAMETER Domain <required>
    The Cohesity authentication domain (default is 'domain.com').

.PARAMETER CompareServer <optional>
    The VIP or FQDN of another Cohesity cluster to compare against.

.EXAMPLE
    .\compareCohesityGflags.ps1 -SourceServer "cohesity.cluster.com" -ReferenceFile "C:\path\to\reference_gflags.json" -Username "admin"

.EXAMPLE
    .\compareCohesityGflags.ps1 -SourceServer "cohesity.cluster.com" -CompareServer "another.cluster.com" -Username "admin"

.NOTES
Author: Doug Austin
Date: 06/16/2025
- Changelog:
    - Initial script creation - 06/16/2025
    - Added functionality to compare current gflags against a reference file - 06/16/2025
    - Improved output formatting - 06/16/2025
    - Added error handling for missing reference file - 06/16/2025
    - Added timestamp formatting for gflags - 06/16/2025
    - Added support for custom domain in authentication - 06/16/2025
    - Added normalization of gflags for comparison - 06/16/2025
    - Added detailed output for differences found - 06/16/2025
    - Added sample reference gflag object output - 06/16/2025
    - Added sorting of gflags for consistent comparison - 06/16/2025
    - Updated comparison logic to only compare flagName and flagValue - 06/16/2025
    - Added support for extracting JSON from zip if ReferenceFile not provided - 06/16/2025
    - Added support for comparing gflags between two clusters - 06/16/2025
    - Added CompareServer parameter to allow comparison against another cluster - 06/16/2025
    - Added ExportOnly switch to export current gflags without comparison - 06/16/2025
    - Added ReferenceDir parameter to specify directory for cluster zip - 06/16/2025
    - Added ReferenceName variable to track source of reference gflags - 06/16/2025
    - Added error handling for missing cluster folder or zip file - 06/16/2025
    - Added extraction of gflags JSON from zip file if not provided - 06/16/2025
    - Added detailed comments and documentation - 06/16/2025
    - Updated script to handle both JSON file and cluster comparison seamlessly - 06/16/2025
    # @"
#>  

param(
    [string]$SourceServer,               # <Cluster VIP or FQDN>
    [string]$ReferenceFile,              # <Path to reference gflags file>
    [string]$ReferenceDir,               # <Path to directory containing cluster zip>
    [string]$Username,                   # <Cohesity username>
    [string]$Domain = 'domain.com',      # <Cohesity authentication domain>
    [string]$CompareServer,              # <Cluster VIP or FQDN to compare against>
    [switch]$ExportOnly                  # <If set, only export current gflags and skip comparison>
)

# Load Cohesity API Helper
. "$PSScriptRoot\cohesity-api.ps1"

# Helper function to get gflags from a cluster
function Get-ClusterGflags {
    param($vip, $username, $domain)
    apiauth -vip $vip -username $username -domain $domain
    $gflags = (api get /nexus/cluster/list_gflags).servicesGflags
    $result = @()
    foreach($service in $gflags){
        $svcName = $service.serviceName
        foreach($serviceGflag in $service.gflags){
            $timeStamp = ''
            if($serviceGflag.timestamp -ne 0){
                $timeStamp = $(usecsToDate ($serviceGflag.timestamp * 1000000)).ToString('yyyy-MM-dd')
            }
            $result += [PSCustomObject]@{
                serviceName = $svcName
                flagName    = $serviceGflag.name
                flagValue   = $serviceGflag.value
                reason      = $serviceGflag.reason
                timestamp   = $timeStamp
            }
        }
    }
    return $result
}

if ($ExportOnly) {
    $currentGflags = Get-ClusterGflags -vip $SourceServer -username $Username -domain $Domain
    $exportFile = "$PSScriptRoot\gflags_export_${SourceServer}_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
    $currentGflags | ConvertTo-Json -Depth 5 | Set-Content $exportFile
    Write-Host "Exported current gflags to $exportFile" -ForegroundColor Green
    exit 0
}

if ($CompareServer) {
    # Get gflags from both clusters
    $currentGflags = Get-ClusterGflags -vip $SourceServer -username $Username -domain $Domain
    $compareGflags = Get-ClusterGflags -vip $CompareServer -username $Username -domain $Domain
    $referenceGflags = $compareGflags
    $referenceName = $CompareServer
} else {
    # Existing logic for JSON/zip
    if (-not $ReferenceFile) {
        $clusterFolder = "\\n002814\winfileservices_cpz_03\Cohesity\Cluster_Exports\$SourceServer\" # <base directory for cluster exports>
        if (!(Test-Path $clusterFolder)) {
            Write-Host "Cluster folder not found: $clusterFolder" -ForegroundColor Red
            exit 1
        }
        $zipPattern = "$SourceServer-configs-*.zip"
        $zipFile = Get-ChildItem -Path $clusterFolder -Filter $zipPattern | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if (-not $zipFile) {
            Write-Host "No config zip file found in $clusterFolder matching $zipPattern" -ForegroundColor Red
            exit 1
        }
        $zipPath = $zipFile.FullName
        $jsonName = "$SourceServer-gflags.json"
        $tempDir = Join-Path $env:TEMP "gflags_compare_$([guid]::NewGuid())"
        New-Item -ItemType Directory -Path $tempDir | Out-Null
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory($zipPath, $tempDir)
        $ReferenceFile = Join-Path $tempDir $jsonName
        if (!(Test-Path $ReferenceFile)) {
            Write-Host "gflags JSON file not found in zip: $ReferenceFile" -ForegroundColor Red
            exit 1
        }
        Write-Host "Extracted $ReferenceFile from $zipPath" -ForegroundColor Cyan
    }
    if (!(Test-Path $ReferenceFile)) {
        Write-Host "Reference file not found: $ReferenceFile" -ForegroundColor Red
        exit 1
    }
    $referenceGflags = Get-Content $ReferenceFile | ConvertFrom-Json
    # Flatten reference gflags to match current gflags structure
    $flatReferenceGflags = @()
    foreach ($service in $referenceGflags) {
        $svcName = $service.serviceName
        foreach ($gflag in $service.gflags) {
            $timeStamp = ''
            if ($gflag.timestamp -ne 0) {
                $timeStamp = $(usecsToDate ($gflag.timestamp * 1000000)).ToString('yyyy-MM-dd')
            }
            $flatReferenceGflags += [PSCustomObject]@{
                serviceName = $svcName
                flagName    = $gflag.name
                flagValue   = $gflag.value
                reason      = $gflag.reason
                timestamp   = $timeStamp
            }
        }
    }
    $referenceGflags = $flatReferenceGflags
    $referenceName = "JSON File"
}

# Normalize and sort both arrays
function Normalize-Gflag {
    param($obj)
    [PSCustomObject]@{
        serviceName = "$($obj.serviceName)".ToLower().Trim()
        flagName    = "$($obj.flagName)".ToLower().Trim()
        flagValue   = "$($obj.flagValue)".ToUpper().Trim()
        reason      = "$($obj.reason)".Trim()
        timestamp   = if ("$($obj.timestamp)") { "$($obj.timestamp)".Trim() } else { "" }
    }
}

$currentGflags = Get-ClusterGflags -vip $SourceServer -username $Username -domain $Domain
$normalizedCurrent = $currentGflags | ForEach-Object { Normalize-Gflag $_ } | Sort-Object serviceName, flagName
$normalizedReference = $referenceGflags | ForEach-Object { Normalize-Gflag $_ } | Sort-Object serviceName, flagName

# Build a lookup for simpler comparison
$refLookup = @{}
foreach ($item in $normalizedReference) {
    $key = "$($item.serviceName)|$($item.flagName)"
    $refLookup[$key] = $item
}
$curLookup = @{}
foreach ($item in $normalizedCurrent) {
    $key = "$($item.serviceName)|$($item.flagName)"
    $curLookup[$key] = $item
}

# Get all unique keys
$allKeys = $refLookup.Keys + $curLookup.Keys | Sort-Object -Unique

# Build a comparison table
$comparison = foreach ($key in $allKeys) {
    $ref = $refLookup[$key]
    $cur = $curLookup[$key]
    if (-not $ref) {
        # Only Looking at Cluster gflags
        [PSCustomObject]@{
            serviceName         = $cur.serviceName
            flagName            = $cur.flagName
            JSONFile_flagValue  = ""
            Current_flagValue   = $cur.flagValue
            JSONFile_reason     = ""
            Current_reason      = $cur.reason
            JSONFile_timestamp  = ""
            Current_timestamp   = $cur.timestamp
            Status              = "Only on Cluster"
        }
    } elseif (-not $cur) {
        # Only in reference JSON file
        [PSCustomObject]@{
            serviceName         = $ref.serviceName
            flagName            = $ref.flagName
            JSONFile_flagValue  = $ref.flagValue
            Current_flagValue   = ""
            JSONFile_reason     = $ref.reason
            Current_reason      = ""
            JSONFile_timestamp  = $ref.timestamp
            Current_timestamp   = ""
            Status              = "Only in JSON File"
        }
    } elseif (
        $ref.flagValue -ne $cur.flagValue -or
        $ref.flagName -ne $cur.flagName
    ) {
        # Exists in both but values differ
        [PSCustomObject]@{
            serviceName         = $ref.serviceName
            flagName            = $ref.flagName
            JSONFile_flagValue  = $ref.flagValue
            Current_flagValue   = $cur.flagValue
            JSONFile_reason     = $ref.reason
            Current_reason      = $cur.reason
            JSONFile_timestamp  = $ref.timestamp
            Current_timestamp   = $cur.timestamp
            Status              = "Different"
        }
    }
}

if ($comparison) {
    Write-Host "`nDifferences found:" -ForegroundColor Yellow
    $comparison | Format-Table serviceName, flagName, JSONFile_flagValue, Current_flagValue, Status -AutoSize
} else {
    Write-Host "`nNo differences found between current and reference gflags." -ForegroundColor Green
}