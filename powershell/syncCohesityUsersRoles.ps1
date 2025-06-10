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
Date: 2025-05-29

If using a targetVips file, it must be in the same folder as this script.
#>

param (
    [string]$sourceVip,
    [string[]]$targetVips,
    [string]$username,
    [string]$domain = 'domain.com',
    [switch]$forceSync
)

# --- Local User Parameters ---
$localDomain = "LOCAL"
$allowedLocalUser = "adminp2"

# --- Cohesity Api Connect Script ---
. "$PSScriptRoot\cohesity-api.ps1"

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

# --- Key Builder Functions ---
function Build-UserKey($user) {
    return "$($user.domain.ToLower())\$($user.username.ToLower())"
}
function Build-GroupKey($group) {
    return "$($group.domain.ToLower())\$($group.name.ToLower())"
}
function Build-RoleKey($role) {
    return $role.name
}

# --- Sync Functions ---
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
function Sync-User($user, $isUpdate = $false) {
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
        if ($isUpdate) {
            $uri = "/public/users/$($user.domain)/$($user.username)"
            Write-Host "Updating user: $userKey" -ForegroundColor Cyan
            api put $uri $body
        } else {
            Write-Host "Creating user: $userKey" -ForegroundColor Cyan
            api post /public/users $body
        }
        Write-Host "Synced user: $userKey" -ForegroundColor DarkGreen -BackgroundColor Green
    } catch {
        Write-Host "Failed to sync user: $userKey" -ForegroundColor Red
        Write-Host ($_.Exception.Message) -ForegroundColor Yellow
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

# --- Remove Functions ---
function Remove-User($user) {
    $userKey = "$($user.domain)\$($user.username)"
    try {
        $body = @{
            domain = $user.domain
            users  = @($user.username)
        }
        api delete /public/users $body
        Write-Host "Removed user: $userKey" -ForegroundColor Yellow
    } catch {
        Write-Host "Failed to remove user: $userKey" -ForegroundColor Red
        Write-Host $_.Exception.Message
    }
}
function Remove-Role($role) {
    try {
        api delete "/public/roles/$($role.name)"
        Write-Host "Removed custom role: $($role.name)" -ForegroundColor Yellow
    } catch {
        Write-Host "Failed to remove role: $($role.name)" -ForegroundColor Red
        Write-Host $_.Exception.Message
    }
}
function Remove-Group($group) {
    try {
        api delete "/public/groups/$($group.domain)/$($group.name)"
        Write-Host "Removed group: $($group.name)" -ForegroundColor Yellow
    } catch {
        Write-Host "Failed to remove group: $($group.name)" -ForegroundColor Red
        Write-Host $_.Exception.Message
    }
}

# --- Comparison Functions ---
function Compare-ClusterState {
    param (
        $sourceRoles, $targetRoles,
        $sourceUsers, $targetUsers,
        $sourceGroups, $targetGroups
    )

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
    $sourceRoleKeys = @{}
    foreach ($role in $sourceRoles) { $sourceRoleKeys[(Build-RoleKey $role)] = $true }
    $rolesToRemove = @()
    foreach ($role in $targetRoles) {
        $roleKey = Build-RoleKey $role
        if (-not $sourceRoleKeys.ContainsKey($roleKey)) {
            $rolesToRemove += $role
        }
    }

    $targetUserTable = @{}
    foreach ($u in $targetUsers) { $targetUserTable[(Build-UserKey $u)] = $u }
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
    $sourceUserKeys = @{}
    foreach ($user in $sourceUsers) { $sourceUserKeys[(Build-UserKey $user)] = $true }
    $usersToRemove = @()
    foreach ($user in $targetUsers) {
        $userKey = Build-UserKey $user
        if (-not $sourceUserKeys.ContainsKey($userKey)) {
            if ($user.domain -eq $localDomain -and $user.username -eq $allowedLocalUser) { continue }
            $usersToRemove += $user
        }
    }

    $targetGroupTable = @{}
    foreach ($g in $targetGroups) { $targetGroupTable[(Build-GroupKey $g)] = $g }
    $missingGroups = @()
    foreach ($group in $sourceGroups) {
        $groupKey = Build-GroupKey $group
        $match = $targetGroupTable[$groupKey]
        if (-not $match) {
            $missingGroups += $group
        }
    }
    $sourceGroupKeys = @{}
    foreach ($group in $sourceGroups) { $sourceGroupKeys[(Build-GroupKey $group)] = $true }
    $groupsToRemove = @()
    foreach ($group in $targetGroups) {
        $groupKey = Build-GroupKey $group
        if (-not $sourceGroupKeys.ContainsKey($groupKey)) {
            $groupsToRemove += $group
        }
    }

    return @{
        MissingRoles = $missingRoles
        RoleDiffs = $roleDiffs
        RolesToRemove = $rolesToRemove
        MissingUsers = $missingUsers
        RoleMismatchedUsers = $roleMismatchedUsers
        UsersToRemove = $usersToRemove
        MissingGroups = $missingGroups
        GroupsToRemove = $groupsToRemove
    }
}

# --- Per-Cluster Sync Function ---
function Sync-Cluster {
    param (
        [string]$TargetVip
    )

    Write-Host "`nConnecting to target cluster: $TargetVip" -ForegroundColor Cyan
    apiauth -vip $TargetVip -username $username -domain $domain

    $targetUsers = api get /public/users | Where-Object { $_.domain -ne $localDomain -or $_.username -eq $allowedLocalUser }
    $targetGroups = api get /public/groups | Where-Object { $_.domain -ne $localDomain }
    $targetRoles = api get /public/roles | Where-Object { $_.isCustomRole -eq $true }

    $diffs = Compare-ClusterState -sourceRoles $sourceRoles -targetRoles $targetRoles `
        -sourceUsers $sourceUsers -targetUsers $targetUsers `
        -sourceGroups $sourceGroups -targetGroups $targetGroups

    $hasDifferences = $diffs.MissingRoles.Count -gt 0 -or $diffs.RoleDiffs.Count -gt 0 -or `
        $diffs.MissingUsers.Count -gt 0 -or $diffs.RoleMismatchedUsers.Count -gt 0 -or `
        $diffs.MissingGroups.Count -gt 0 -or $diffs.UsersToRemove.Count -gt 0 -or `
        $diffs.RolesToRemove.Count -gt 0 -or $diffs.GroupsToRemove.Count -gt 0

    if (-not $hasDifferences) {
        Write-Host "Source and target cluster $TargetVip are already in sync. No updates needed." -ForegroundColor Green
        return
    }

    if (-not $forceSync) {
        Write-Host "Differences detected for $TargetVip. Would you like to synchronize these to the target cluster?"
        $syncConfirm = Read-Host "Type 'Y' to proceed or anything else to cancel"
        if ($syncConfirm -ne 'Y') {
            Write-Host "Synchronization cancelled by user for $TargetVip."
            return
        }
    } else {
        Write-Host "Differences detected for $TargetVip. Forcing synchronization due to -forceSync flag." -ForegroundColor Yellow
    }

    foreach ($role in $diffs.MissingRoles) {
        Sync-Role $role $true
    }
    foreach ($role in $diffs.RoleDiffs) {
        Sync-Role $role $false
    }
    foreach ($user in $diffs.MissingUsers) {
        Sync-User $user $false
    }
    foreach ($user in $diffs.RoleMismatchedUsers) {
        Sync-User $user $true
    }
    foreach ($group in $diffs.MissingGroups) {
        Sync-Group $group
    }
    foreach ($user in $diffs.UsersToRemove) {
        Remove-User $user
    }
    foreach ($role in $diffs.RolesToRemove) {
        Remove-Role $role
    }
    foreach ($group in $diffs.GroupsToRemove) {
        Remove-Group $group
    }

    if (Get-Command -Name apidrop -ErrorAction SilentlyContinue) {
        apidrop
    }

    Write-Host "Synchronization complete for $TargetVip." -ForegroundColor DarkGreen -BackgroundColor Green
}

# --- Connect to Source Cluster and Gather Data ---
Write-Host "`nConnecting to source cluster: $sourceVip" -ForegroundColor Cyan
apiauth -vip $sourceVip -username $username -domain $domain
$sourceUsers = api get /public/users | Where-Object { $_.domain -ne $localDomain -or $_.username -eq $allowedLocalUser }
$sourceGroups = api get /public/groups | Where-Object { $_.domain -ne $localDomain }
$sourceRoles = api get /public/roles | Where-Object { $_.isCustomRole -eq $true }
foreach ($role in $sourceRoles) {
    $role | Add-Member -MemberType NoteProperty -Name PrivString -Value ((@($role.privileges | Sort-Object -Unique) -join ','))
}

# --- Main Loop ---
foreach ($targetVip in $targetVips) {
    Sync-Cluster -TargetVip $targetVip
}