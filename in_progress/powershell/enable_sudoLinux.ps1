<#
.SYNOPSIS
Exports Cohesity user and group accounts (non-LOCAL) from a cluster.

.DESCRIPTION
Connects to a Cohesity cluster and exports all AD/SSO users and groups (excluding LOCAL) into a JSON file.

.PARAMETER vip
The FQDN or IP address of the Cohesity cluster.

.PARAMETER user
The username for Cohesity authentication.

.PARAMETER domain
The domain of the user account (e.g., LOCAL or AD domain).

.EXAMPLE
.\export_roles.ps1 -vip cohesity.domain.com -user user01 -domain domain.com

.NOTES
Author: Doug Austin  
Date: 05/12/2025  
Changelog:
  - Initial version for exporting accounts
  - Refactored for dynamic input and help
#>
# Load Cohesity API Helper
. "$PSScriptRoot\cohesity-api.ps1"

# === Parameters ===
$vip = "asx1cdr1gcl-az"  # cohesity-cluster.domain.com
$username = "condoua2a"
$domain = "cguser.capgroup.com"

# Authenticate
apiauth -vip $vip -username $username -domain $domain

# Enable sudo access
$body = @{
    sudoAccessEnable = $true
}

try {
    api put /public/users/linuxSupportUserSudoAccess $body
    Write-Host "Sudo access enabled for linuxSupport user." -ForegroundColor Green
} catch {
    Write-Host "Failed to enable sudo access." -ForegroundColor Red
    Write-Host $_.Exception.Message
}
