# Load Cohesity API Helper
# cohesity-api.ps1 must be in the same folder as this script
. .\cohesity-api.ps1

# ==Config==

$vip = 'cluster' 
$username = 'admin' # user with api access
$domain = 'local' # domain of user account
# Script will prompt for password

apiauth -vip $vip -username $username -domain $domain

# Get defined list of roles
$roles = Get-Content -Raw -Path 'default_roles_export.json' | ConvertFrom-Json

Write-Host "Found $($roles.Count) roles in export file"

# Get Currently Defined Roles
$currentRoles = api get /public/roles
$currentRoleNames = $currentRoles.names

Write-Host "Loaded $($roles.Count) roles to sync"

foreach ($role in $roles) {
    # Only Sync Custom Roles
    if ($role.isCustomRole -ne $true) {
        Write-Host "Skipping Built-in role: $($role.name)"
        continue
    }

    $roleName = $role.name
    $roleDescription = $role.description
    $rolePrivileges = $($role.privileges)

    if ($currentRoleNames -contains $roleName) {
        # Update Existing Role
        $putBody = @{
            description = $roleDescription
            privileges = $rolePrivileges
        }
        try {
            api put "/public/roles/$roleName" $putBody
            Write-Host "Updated role: $roleName"
        } catch {
            Write-Host " Failed to update role: $roleName"
            Write-Host $_.Exception.Message
        }
    } else {
        # Create New Role
        $postBody = @{
            name = $roleName
            description = $roleDescription
            privileges = $rolePrivileges
        }
        try {
            api post "/public/roles" $postBody
            Write-Host "Created role: $roleName"
        } catch {
            Write-Host "Failed to create role: $roleName"
            Write-Host $_.Exception.Message
        }
    }
}