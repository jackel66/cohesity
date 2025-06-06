<# 
.SYNOPSIS
Export and import vSphere tags within a specific category.

.PARAMETER SourceServer
vCenter server to export tags from.

.PARAMETER TargetServer
vCenter server to import tags to.

.PARAMETER Category
The tag category to export/import.

.PARAMETER Export
Switch to export tags.

.PARAMETER Import
Switch to import tags.

.PARAMETER File
Path to export/import file. Default: .\vsphere-tags.json

.EXAMPLE
# Export tags
.\syncVMTags.ps1 -SourceServer vcenter1.domain.com -Category "MyCategory" -Export -File .\tags.json

# Import tags
.\syncVMTagsTags.ps1 -TargetServer vcenter2.domain.com -Category "MyCategory" -Import -File .\tags.json
#>

param(
    [string]$SourceServer = "vcenter server", # Update with your vCenter server
    [string]$TargetServer, # Optional, if not specified, will only export
    [string]$username = "username", # Update with your vCenter username
    [string]$Category = "Category", # The tag category to export/import
    [switch]$Export,
    [switch]$Import,
    [string]$File = ".\vsphere-tags.json" # Default export/import file path, update as needed
)


if ($Export) {
    if (-not $SourceServer -or -not $Category) {
        throw "SourceServer and Category are required for export."
    }
    $srcCred = Get-Credential -Message "Enter credentials for $SourceServer"
    Connect-VIServer -Server $SourceServer -Credential $srcCred

    $cat = Get-TagCategory -Name $Category -ErrorAction Stop
    $tags = Get-Tag -Category $cat

    $export = @()
    foreach ($tag in $tags) {
        $export += [PSCustomObject]@{
            Name        = $tag.Name
            Description = $tag.Description
            Category    = $tag.Category.Name
        }
    }
    $export | ConvertTo-Json | Set-Content $File
    Write-Host "Exported $($export.Count) tags from category '$Category' to $File" -ForegroundColor Green
    Disconnect-VIServer -Server $SourceServer -Confirm:$false
    exit 0
}

if ($Import) {
    if (-not $TargetServer -or -not $Category) {
        throw "TargetServer and Category are required for import."
    }
    if (-not (Test-Path $File)) {
        throw "File $File not found."
    }
    $tgtCred = Get-Credential -Message "Enter credentials for $TargetServer"
    Connect-VIServer -Server $TargetServer -Credential $tgtCred

    # Ensure category exists
    $cat = Get-TagCategory -Name $Category -ErrorAction SilentlyContinue
    if (-not $cat) {
        # You may want to customize category creation as needed
        $cat = New-TagCategory -Name $Category -Cardinality Single -EntityType VirtualMachine
        Write-Host "Created category '$Category'" -ForegroundColor Yellow
    }

    $tags = Get-Content $File | ConvertFrom-Json
    foreach ($tag in $tags) {
        if (-not (Get-Tag -Name $tag.Name -Category $Category -ErrorAction SilentlyContinue)) {
            New-Tag -Name $tag.Name -Description $tag.Description -Category $Category
            Write-Host "Imported tag: $($tag.Name)" -ForegroundColor Green
        } else {
            Write-Host "Tag already exists: $($tag.Name)" -ForegroundColor Yellow
        }
    }
    Disconnect-VIServer -Server $TargetServer -Confirm:$false
    exit 0
}

Write-Host "Specify -Export or -Import. Use -? for help." -ForegroundColor Yellow
exit 1