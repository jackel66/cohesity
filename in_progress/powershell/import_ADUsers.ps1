# Load Cohesity API Helper
# cohesity-api.ps1 must be in the same folder as this script
. .\cohesity-api.ps1


# Auth to destination cluster
$vip = 'cluster'
$username = 'admin'
$domain = 'LOCAL'
apiauth -vip $vip -username $username -domain $domain

# Load export
$data = Get-Content -Raw -Path 'sjx1cdp1dcl-az.account_export.json' | ConvertFrom-Json
$usersToImport = $data.users
$groupsToImport = $data.groups

# Get current users and groups
$currentUsers = api get /public/users
$currentGroups = api get /public/groups

$currentUserIds = $currentUsers | ForEach-Object { "$($_.domain)\$($_.username)" }
$currentGroupIds = $currentGroups | ForEach-Object { "$($_.domain)\$($_.name)" }

# Import users
foreach ($user in $usersToImport) {
    $userKey = "$($user.domain)\$($user.username)"
    if ($currentUserIds -contains $userKey) {
        Write-Host "⏭️  User exists: $userKey"
        continue
    }

    if ($user.domain -eq "LOCAL") {
        Write-Host "⏭️  Skipping LOCAL user: $userKey"
        continue
    }

    $body = @{
        username     = $user.username
        domain       = $user.domain
        roles        = $user.roles
        emailAddress = $user.emailAddress
    }

    try {
        api post /public/users $body
        Write-Host "✅ Created user: $userKey"
    } catch {
        Write-Host "❌ Failed to create user: $userKey"
        Write-Host $_.Exception.Message
    }
}

# Import groups
foreach ($group in $groupsToImport) {
    $groupKey = "$($group.domain)\$($group.name)"
    if ($currentGroupIds -contains $groupKey) {
        Write-Host "⏭️  Group exists: $groupKey"
        continue
    }

    if ($group.domain -eq "LOCAL") {
        Write-Host "⏭️  Skipping LOCAL group: $groupKey"
        continue
    }

    $body = @{
        name   = $group.name
        domain = $group.domain
        roles  = $group.roles
    }

    try {
        api post /public/groups $body
        Write-Host "✅ Created group: $groupKey"
    } catch {
        Write-Host "❌ Failed to create group: $groupKey"
        Write-Host $_.Exception.Message
    }
}
