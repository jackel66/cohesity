<#
.SYNOPSIS
Syncs custom Cohesity roles and AD/allowed local users between two clusters.

.PARAMETER sourceVip
Cohesity VIP or FQDN of the source cluster.

.PARAMETER targetVip
Cohesity VIP or FQDN of the target cluster.

.PARAMETER username
API username with permission to read/write users and roles.

.PARAMETER domain
AD domain or 'LOCAL'. Default: cguser.capgroup.com
#>

param (
    [Parameter(Mandatory = $true)]
    [string]$sourceVip,

    [Parameter(Mandatory = $true)]
    [string]$targetVip,

    [Parameter(Mandatory = $true)]
    [string]$username,

    [string]$domain = 'cguser.capgroup.com'
)

# --- Cohesity API Connect Script (must be in same folder as this script) ---
. "$PSScriptRoot\cohesity-api.ps1"

# --- Connect to Source Cluster ---
Write-Host "Connecting to source cluster: $sourceVip" -ForegroundColor Cyan
apiauth -vip $sourceVip -username $username -domain $domain
$sourceUsers = api get /public/users | Where-Object { $_.domain -ne "LOCAL" -or $_.username -eq $allowedLocalUser}
$sourceRoles = api get /public/roles | Where-Object { $_.isCustomRole -eq $true }


# --- Connect to Target Cluster ---
Write-Host "Connecting to target cluster: $targetVip" -ForegroundColor Cyan
apiauth -vip $targetVip -username $username -domain $domain
$targetUsers = api get /public/users | Where-Object { $_.domain -ne "LOCAL"  -or $_.username -eq $allowedLocalUser}
$targetRoles = api get /public/roles | Where-Object { $_.isCustomRole -eq $true }

# --- Compare Roles --- 
$missingRoles = @()
$roleDiffs = @()

Write-Host "Comparing custom roles..." -ForegroundColor Green
foreach ($role in $sourceRoles) {
    $match = $targetRoles | Where-Object { $_.name -eq $role.name }

    if (-not $match) {
        Write-Host "Missing role in target: $($role.name)" -ForegroundColor Yellow
        $missingRoles += $role
    }
    else {
        $sourcePrivs = @($role.privileges | Sort-Object -Unique | ForEach-Object { $_.ToString() })
        $targetPrivs = @($match.privileges | Sort-Object -Unique | ForEach-Object { $_.ToString() })

        # --- Only log and add to diff if the actual sets differ ---
        if (-not ($sourcePrivs -join ',' -eq $targetPrivs -join ',')) {
            Write-Host "Role privilege mismatch: $($role.name)" -ForegroundColor Cyan
            Write-Host "Source privileges: $($sourcePrivs -join ', ')" -ForegroundColor DarkGray
            Write-Host "Target privileges: $($targetPrivs -join ', ')" -ForegroundColor DarkGray

            $diff = Compare-Object -ReferenceObject $sourcePrivs -DifferenceObject $targetPrivs
            if ($diff) {
                Write-Host "Detailed differences:" -ForegroundColor Yellow
                $diff | ForEach-Object {
                    $side = if ($_.SideIndicator -eq '=>') { 'Target only' } else { 'Source only' }
                    Write-Host "    $($side): $($_.InputObject)"
                }
            }

            $roleDiffs += $role
        }
    }
}


# --- Compare Users ---
$missingUsers = @()
$roleMismatchedUsers = @()
Write-Host "Comparing users..." -ForegroundColor Green
foreach ($user in $sourceUsers) {
    $match = $targetUsers | Where-Object {
        $_.username.ToLower() -eq $user.username.ToLower() -and 
        $_.domain.ToLower() -eq $user.domain.ToLower()
    }
    $key = "$($user.domain)\$($user.username)"
    if (-not $match) {
        Write-Host "Missing user in target: $key" -ForegroundColor Yellow
        $missingUsers += $user
    }
    elseif (($match.roles | Sort-Object) -ne ($user.roles | Sort-Object)) {
        Write-Host "Role mismatch for user: $key" -ForegroundColor Cyan
        Write-Host "   Source: $($user.roles -join ', ')"
        Write-Host "   Target: $($match.roles -join ', ')"
        $roleMismatchedUsers += $user
    }
}

# --- Summary ---
$hasDifferences = $missingRoles.Count -gt 0 -or $roleDiffs.Count -gt 0 -or $missingUsers.Count -gt 0 -or $roleMismatchedUsers.Count -gt 0
if (-not $hasDifferences) {
    Write-Host "Source and target clusters are in sync. No updates needed!!" -ForegroundColor DarkGreen -BackgroundColor Green
    exit
}

# --- Prompt for Sync ---
Write-Host "`nDifferences detected. Would you like to synchronize these to the target cluster? [Yy/Nn]"
$syncConfirm = Read-Host "Type 'Y/y' to proceed or anything else to cancel"
if ($syncConfirm -ne 'Y') {
    Write-Host "Synchronization cancelled by user."
    exit
}

# --- Sync Roles ---
foreach ($role in $missingRoles) {
    $body = @{
        name = $role.name
        label = $role.label
        description = $role.description
        privileges = $role.privileges
        isCustomRole = $true
    }

    try {
        api post /public/roles $body
        Write-Host "Created role: $($role.name)" -ForegroundColor Green
    } catch {
        Write-Host "Failed to create role: $($role.name)"- -ForegroundColor Red
        Write-Host $_.Exception.Message
    }
}
foreach ($role in $roleDiffs) {

    if (-not $role.PSObject.Properties['privileges'] -or !$role.privileges -or $role.privileges.Count -eq 0) {
        Write-Host "Skipping update: no privileges specific for role '$($role.name)'" -ForegroundColor Yellow
        continue
    }

    $body = @{
        name            = $role.Name
        label           = $role.label
        description     = $role.description
        privileges      = @($role.privileges | ForEach-Object { $_.ToString() })
        isCustomRole    = $true
    }

    try {
        api put "/public/roles/$($role.name)" $body
        Write-Host "Updated role: $($role.name)" -ForegroundColor DarkGreen -BackgroundColor Green
    } catch {
        Write-Host "Failed to update role: $($role.name)" -ForegroundColor Red
        Write-Host $_.Exception.Message
    }
}


# --- Sync Users ---
$allowedLocalUser = "adminp2"
foreach ($user in $missingUsers + $roleMismatchedUsers) {
    $userKey = "($user.domain)\$($user.username)"

    if ($user.domain -eq "LOCAL" -and $user.username -ne $allowedLocalUser)  {
        Write-Host "Skipping Local user: $userKey"
        continue
    }

    $body = @{
        username     = $user.username
        domain       = $user.domain
        roles        = $user.roles
        emailAddress = $user.emailAddress
    }
    # --- Add password for Local user Creation ---
    if ($user.domain -eq "LOCAL") {
        $body["password"] = "****" # <--Temp Local User Password
    }

    try {
        api post /public/users $body
        Write-Host "Synced user: $($user.domain)\\$($user.username)" -ForegroundColor DarkGreen -BackgroundColor Green
    } catch {
        Write-Host "Failed to sync user: $userKey" -ForegroundColor Red
        Write-Host $_.Exception.Message
    }

}

Write-Host "Synchronization complete." -ForegroundColor DarkGreen -BackgroundColor Green