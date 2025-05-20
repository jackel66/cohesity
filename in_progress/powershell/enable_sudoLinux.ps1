<#
.SYNOPSIS
Enables sudo access for the linuxSupport user on a Cohesity cluster.

.DESCRIPTION
This script authenticates to a Cohesity cluster and enables sudo access for the built-in linuxSupport user 
by invoking the appropriate REST API.

.PARAMETER vip
The VIP or FQDN of the Cohesity cluster.

.PARAMETER user
The username for Cohesity authentication.

.PARAMETER domain
The domain of the user account (e.g., LOCAL or AD domain).

.EXAMPLE
.\enable_sudo_access.ps1 -vip cohesity.domain.com -user admin -domain LOCAL

.NOTES
Author: Doug Austin  
Date: 2025-05-20  
Changelog:
  - Initial version for enabling sudo access
#>

param (
    [Parameter(Mandatory = $false)]
    [string]$vip,

    [Parameter(Mandatory = $false)]
    [string]$user,

    [Parameter(Mandatory = $false)]
    [string]$domain = "LOCAL"
)

# Prompt if not supplied
if (-not $vip) { $vip = Read-Host "Enter Cohesity cluster VIP or FQDN" }
if (-not $user) { $user = Read-Host "Enter username" }
if (-not $domain) { $domain = Read-Host "Enter domain (e.g., LOCAL or your AD domain)" }

# Load Cohesity API Helper
. "$PSScriptRoot\cohesity-api.ps1"

# Authenticate to Cohesity
try {
    apiauth -vip $vip -username $user -domain $domain
    Write-Host "✅ Connected to cluster $vip" -ForegroundColor Cyan
} catch {
    Write-Host "❌ Failed to authenticate to cluster $vip" -ForegroundColor Red
    exit 1
}

# Enable sudo access
$body = @{ sudoAccessEnable = $true }

try {
    api put /public/users/linuxSupportUserSudoAccess $body
    Write-Host "✅ Sudo access enabled for 'linuxSupport' user." -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to enable sudo access." -ForegroundColor Red
    Write-Host $_.Exception.Message
}
