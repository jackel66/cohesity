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
