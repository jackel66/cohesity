<#
.SYNOPSIS
Enables sudo access for the linuxSupport user on a Cohesity cluster.

.DESCRIPTION
Connects to a Cohesity cluster and enables sudo access for the linuxSupport user.

.PARAMETER vip
The VIP or FQDN of the Cohesity cluster

.PARAMETER user
The username for Cohesity authentication.

.PARAMETER domain
The domain of the user account (e.g., LOCAL or AD domain).

.EXAMPLE
.\export_roles.ps1 -vip cohesity.domain.com -user user01 -domain domain.com

.NOTES
Author: Doug Austin  
Date: 05/120/2025  
Changelog:
  - Initial version for enabling sudo access

#>
# Load Cohesity API Helper
. "$PSScriptRoot\cohesity-api.ps1"

# === Parameters ===
$vip = "cluster"  # cohesity-cluster.domain.com
$username = "admin"
$domain = "domain"

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
