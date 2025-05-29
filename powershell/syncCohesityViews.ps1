<#
.SYNOPSIS
Copies all Cohesity views (including share name, permissions, and allow list) from a source cluster to one or more target clusters.

.PARAMETER sourceVip
FQDN or IP of the source Cohesity cluster.

.PARAMETER targetVips
One or more target Cohesity VIPs. Can be passed via parameter or via targetvips.txt.

.PARAMETER username
Username with API access.

.PARAMETER domain
Domain of the username (e.g., domain.com or LOCAL). Defaults to domain.com.

.EXAMPLE
.\syncCohesityViews.ps1 -sourceVip cluster0 -targetVips cluster1,cluster2 -username user -domain domain.com

.EXAMPLE
.\syncCohesityViews.ps1 -sourceVip cluster0 -username user
(Reads targetVips from targetvips.txt)

.NOTES
Author: Doug Austin  
Date: 2025-05-29

#>

param (
    [string]$sourceVip,
    [string[]]$targetVips,
    [string]$username,
    [string]$domain = 'domain.com'
)

if (-not $targetVips) {
    $filePath = "$PSScriptRoot\targetvips_views.txt"
    if (Test-Path $filePath) {
        $targetVips = Get-Content $filePath | Where-Object { $_ -and $_.Trim() -ne "" }
        Write-Host "Loaded $($targetVips.Count) targets from targetvips.txt" -ForegroundColor Cyan
    } else {
        Write-Host "No targetVips provided and targetvips.txt not found." -ForegroundColor Red
        exit 1
    }
}

. "$PSScriptRoot\cohesity-api-helper.ps1"

# --- Connect to Source and get all views ---
Write-Host "`nConnecting to source cluster: $sourceVip" -ForegroundColor Cyan
apiauth -vip $sourceVip -username $username -domain $domain

# Get all views (may need to page if there are many)
$sourceViewsResponse = api get /public/views
$sourceViews = $sourceViewsResponse.views

if (-not $sourceViews) {
    Write-Host "No views found on source cluster." -ForegroundColor Yellow
    exit 0
}

# --- For each target cluster, create missing views ---
foreach ($targetVip in $targetVips) {
    Write-Host "`nConnecting to target cluster: $targetVip" -ForegroundColor Cyan
    apiauth -vip $targetVip -username $username -domain $domain

    $targetViewsResponse = api get /public/views
    $targetViews = $targetViewsResponse.views
    $targetViewNames = @{}
    foreach ($v in $targetViews) {
        if ($null -ne $v.name -and $v.name -ne "") {
            $targetViewNames[$v.name] = $true
        }
    }

    foreach ($view in $sourceViews) {
        if ($null -eq $view.name -or $view.name -eq "") {
            Write-Host "Skipping a view with null or empty name." -ForegroundColor Yellow
            continue
        }
        if ($targetViewNames.ContainsKey($view.name)) {
            Write-Host "View '$($view.name)' already exists on $targetVip. Skipping." -ForegroundColor Yellow
            continue
        }

        # --- Get the ViewBox name from the source view ---
        $viewBoxName = $view.viewBoxName
        if (-not $viewBoxName) {
            # If not present, try to map from viewBoxId (optional, if you have mapping)
            Write-Host "No viewBoxName found for view '$($view.name)'. Skipping." -ForegroundColor Yellow
            continue
        }

        # --- Get the ViewBox ID from the target cluster by name ---
        $targetViewBoxes = api get /public/viewBoxes
        $targetViewBox = $targetViewBoxes | Where-Object { $_.name -eq $viewBoxName }
        if (-not $targetViewBox) {
            Write-Host "ViewBox '$viewBoxName' not found on $targetVip. Skipping view '$($view.name)'." -ForegroundColor Red
            continue
        }
        $targetViewBoxId = $targetViewBox.id

        # Build the body for the new view, including the correct viewBoxId
        $body = @{
            name                        = $view.name
            shareName                   = $view.shareName
            smbFilePermissionsInfo      = $view.smbFilePermissionsInfo
            sharePermissions            = $view.sharePermissions
            accessSids                  = $view.accessSids
            antivirusScanConfig         = $view.antivirusScanConfig
            caseInsensitiveNamesEnabled = $view.caseInsensitiveNamesEnabled
            description                 = $view.description
            enableFastDurableHandle     = $view.enableFastDurableHandle
            viewBoxId                   = $targetViewBoxId
            # Add any other properties you want to preserve
        }

        try {
            api post /public/views $body
            Write-Host "Created view '$($view.name)' on $targetVip." -ForegroundColor Green
        } catch {
            Write-Host "Failed to create view '$($view.name)' on $targetVip." -ForegroundColor Red
            Write-Host $_.Exception.Message
        }
    }

    if (Get-Command -Name apidrop -ErrorAction SilentlyContinue) {
        apidrop
    }

    Write-Host "View synchronization complete for $targetVip." -ForegroundColor DarkGreen -BackgroundColor Green
}