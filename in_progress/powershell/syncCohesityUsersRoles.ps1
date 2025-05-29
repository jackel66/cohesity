<#
.SYNOPSIS
Syncs custom Cohesity roles, AD users, and groups between clusters.

.DESCRIPTION
Compares and optionally syncs Cohesity roles, AD users, and groups from a source cluster to one or more target clusters.

.PARAMETER sourceVip
FQDN or IP of the source Cohesity cluster.

.PARAMETER targetVips
One or more target Cohesity VIPs. Can be passed via parameter or via targetvips.txt.

.PARAMETER username
Username with API access.

.PARAMETER domain
Domain of the username (e.g., cguser.capgroup.com or LOCAL). Defaults to cguser.capgroup.com.

.PARAMETER forceSync
Skips prompts and forces sync of all mismatched users/roles.

.EXAMPLE
.\sync-cohesity.ps1 -sourceVip cluster0 -targetVips cluster1,cluster2 -username user -domain domain.com

.EXAMPLE
.\sync-cohesity.ps1 -sourceVip cluster0 -username user
(Reads targetVips from targetvips.txt)

.NOTES
Author: Doug Austin  
Date: 2025-05-20

If using a targetVips file, it must be in the same folder as this script.
#>

param (
    [string]$sourceVip,
    [string[]]$targetVips,
    [string]$username,
    [string]$domain = 'domain.com'
)

if (-not $targetVips) {
    $filePath = "$PSScriptRoot\targetvips.txt"
    if (Test-Path $filePath) {
        $targetVips = Get-Content $filePath | Where-Object { $_ -and $_.Trim() -ne "" }
        Write-Host "Loaded $($targetVips.Count) targets from targetvips.txt" -ForegroundColor Cyan
    } else {
        Write-Host "No targetVips provided and targetvips.txt not found." -ForegroundColor Red
        exit 1
    }
}

$localDomain = "LOCAL"
$allowedLocalUser = "adminp2"

. "$PSScriptRoot\cohesity-api-helper.ps1"

function Build-UserKey($user) {
    return "$($user.domain.ToLower())\$($user.username.ToLower())"
}
function Build-GroupKey($group) {
    return "$($group.domain.ToLower())\$($group.name.ToLower())"
}
function Build-RoleKey($role) {
    return $role.name
}

# --- Connect to Source ---
Write-Host "`nConnecting to source cluster: $sourceVip" -ForegroundColor Cyan
apiauth -vip $sourceVip -username $username -domain $domain
$sourceUsers = api get /public/users | Where-Object { $_.domain -ne $localDomain -or $_.username -eq $allowedLocalUser }
$sourceGroups = api get /public/groups | Where-Object { $_.domain -ne $localDomain }
$sourceRoles = api get /public/roles | Where-Object { $_.isCustomRole -eq $true }

foreach ($role in $sourceRoles) {
    $role | Add-Member -MemberType NoteProperty -Name PrivString -Value ((@($role.privileges | Sort-Object -Unique) -join ','))
}

function Sync-Role($role, $isNew) {
    $body = @{
        name          = $role.name
        label         = $role.label
        description   = $role.description
        privileges    = $role.privileges
        isCustomRole  = $true
    }
    try {
        $method = if ($isNew) { 'post' } else { 'put' }
        $uri = if ($method -eq 'post') { '/public/roles' } else { "/public/roles/$($role.name)" }
        api $method $uri $body
        Write-Host "Synchronized role: $($role.name)" -ForegroundColor Green
    } catch {
        Write-Host "Failed to sync role: $($role.name)" -ForegroundColor Red
        Write-Host $_.Exception.Message
    }
}
function Sync-User($user) {
    $userKey = "$($user.domain)\$($user.username)"
    if ($user.domain -eq $localDomain -and $user.username -ne $allowedLocalUser) {
        Write-Host "Skipping unapproved LOCAL user: $userKey" -ForegroundColor Yellow
        return
    }
    $body = @{
        username     = $user.username
        domain       = $user.domain
        roles        = $user.roles
        emailAddress = $user.emailAddress
    }
    if ($user.domain -eq $localDomain) {
        $body["password"] = "TempSecureP@ssw0rd!"
    }
    try {
        api post /public/users $body
        Write-Host "Synced user: $userKey" -ForegroundColor DarkGreen -BackgroundColor Green
    } catch {
        Write-Host "Failed to sync user: $userKey" -ForegroundColor Red
        Write-Host $_.Exception.Message
    }
}
function Sync-Group($group) {
    $groupKey = "$($group.domain)\$($group.name)"
    $body = @{
        name   = $group.name
        domain = $group.domain
        roles  = $group.roles
    }
    try {
        api post /public/groups $body
        Write-Host "Synced group: $groupKey" -ForegroundColor Green
    } catch {
        Write-Host "Failed to sync group: $groupKey" -ForegroundColor Red
        Write-Host $_.Exception.Message
    }
}

# --- For each target cluster, compare and sync ---
foreach ($targetVip in $targetVips) {
    Write-Host "`nConnecting to target cluster: $targetVip" -ForegroundColor Cyan
    apiauth -vip $targetVip -username $username -domain $domain

    $targetUsers = api get /public/users | Where-Object { $_.domain -ne $localDomain -or $_.username -eq $allowedLocalUser }
    $targetGroups = api get /public/groups | Where-Object { $_.domain -ne $localDomain }
    $targetRoles = api get /public/roles | Where-Object { $_.isCustomRole -eq $true }

    $targetUserTable = @{}
    foreach ($u in $targetUsers) { $targetUserTable[(Build-UserKey $u)] = $u }
    $targetGroupTable = @{}
    foreach ($g in $targetGroups) { $targetGroupTable[(Build-GroupKey $g)] = $g }
    $targetRoleTable = @{}
    foreach ($r in $targetRoles) { $targetRoleTable[(Build-RoleKey $r)] = $r }
    foreach ($role in $targetRoles) {
        $role | Add-Member -MemberType NoteProperty -Name PrivString -Value ((@($role.privileges | Sort-Object -Unique) -join ','))
    }

    $missingRoles = @()
    $roleDiffs = @()
    foreach ($role in $sourceRoles) {
        $roleKey = Build-RoleKey $role
        $match = $targetRoleTable[$roleKey]
        if (-not $match) {
            $missingRoles += $role
        }
        elseif ($role.PrivString -ne $match.PrivString) {
            $roleDiffs += $role
        }
    }

    $missingUsers = @()
    $roleMismatchedUsers = @()
    foreach ($user in $sourceUsers) {
        $userKey = Build-UserKey $user
        $match = $targetUserTable[$userKey]
        if (-not $match) {
            $missingUsers += $user
        }
        else {
            $sourceRolesStr = (@($user.roles | Sort-Object -Unique) -join ',')
            $targetRolesStr = (@($match.roles | Sort-Object -Unique) -join ',')
            if ($sourceRolesStr -ne $targetRolesStr) {
                $roleMismatchedUsers += $user
            }
        }
    }

    $missingGroups = @()
    foreach ($group in $sourceGroups) {
        $groupKey = Build-GroupKey $group
        $match = $targetGroupTable[$groupKey]
        if (-not $match) {
            $missingGroups += $group
        }
    }

    $hasDifferences = $missingRoles.Count -gt 0 -or $roleDiffs.Count -gt 0 -or $missingUsers.Count -gt 0 -or $roleMismatchedUsers.Count -gt 0 -or $missingGroups.Count -gt 0

    if (-not $hasDifferences) {
        Write-Host "Source and target cluster $targetVip are already in sync. No updates needed." -ForegroundColor Green
        continue
    }

    Write-Host "Differences detected for $targetVip. Would you like to synchronize these to the target cluster?"
    $syncConfirm = Read-Host "Type 'Y' to proceed or anything else to cancel"
    if ($syncConfirm -ne 'Y') {
        Write-Host "Synchronization cancelled by user for $targetVip."
        continue
    }

    foreach ($role in $missingRoles) {
        Sync-Role $role $true
    }
    foreach ($role in $roleDiffs) {
        Sync-Role $role $false
    }
    foreach ($user in $missingUsers) {
        Sync-User $user
    }
    foreach ($user in $roleMismatchedUsers) {
        Sync-User $user
    }
    foreach ($group in $missingGroups) {
        Sync-Group $group
    }

    # Optionally clear session or disconnect here if your helper supports it
    if (Get-Command -Name apidrop -ErrorAction SilentlyContinue) {
        apidrop
    }

    Write-Host "Synchronization complete for $targetVip." -ForegroundColor DarkGreen -BackgroundColor Green
}