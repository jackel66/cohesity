param (
    [string]$source,
    [string]$username,
    [string]$domain = 'cguser.capgroup.com'
)

. "$PSScriptRoot\cohesity-api.ps1"

# Authenticate to Cohesity cluster
apiauth -vip $source -Username $username -Domain $domain

$jobs = api get clusters/nodes -v2 | ConvertFrom-Json

$jobs | ForEach-Object {
    [PSCustomObject]@{
        coheistyNodeSerial = $_.'cohesityNodeSerial'
        id                 = $_.'id'
        ip                 = $_.'ip'
        chassisName        = $_.chassisInfo.chassisName
        chassisSerial      = $_.chassisInfo.chassisSerial
        hostname           = $_.hostName
    }
}