<#
.SYNOPSIS
Export and import Cohesity protection policies starting with 'CG-'.

.PARAMETER sourceVip
Cohesity VIP or FQDN of the source cluster.

.PARAMETER targetVip
Cohesity VIP or FQDN of the target cluster.

.PARAMETER username
API username with permission to read/write protection policies.

.PARAMETER domain
AD domain or 'LOCAL'. Default: domain.com

.PARAMETER export
Switch to export policies.

.PARAMETER import
Switch to import policies.

.PARAMETER file
Path to export/import file. Default: .\cg-policies.json

.PARAMETER replicationTarget
Replication target name to use during import.

.EXAMPLE
# Export
.\exportImport-CG-ProtectionPolicies.ps1 -sourceVip src -username admin -domain domain.com -export -file .\cg-policies.json

# Import
.\exportImport-CG-ProtectionPolicies.ps1 -targetVip tgt -username admin -domain domain.com -import -file .\cg-policies.json -replicationTarget "NewReplicationTarget"
#>

param(
    [string]$sourceVip,
    [string]$targetVip,
    [string]$username,
    [string]$domain = 'domain.com',
    [switch]$export,
    [switch]$import,
    [string]$file = ".\cg-policies.json",
    [string]$replicationTarget
)

. "$PSScriptRoot\cohesity-api.ps1"

if ($export) {
    if (-not $sourceVip) { throw "sourceVip is required for export." }
    apiauth -vip $sourceVip -username $username -domain $domain

    Write-Host "Fetching protection policies from $sourceVip..." -ForegroundColor Cyan
    $policies = api get /public/protectionPolicies | Where-Object { $_.name -like 'CG-*' }
    if (-not $policies) {
        Write-Host "No policies found starting with CG-." -ForegroundColor Yellow
        exit 0
    }
    $policies | ConvertTo-Json -Depth 10 | Set-Content $file
    Write-Host "Exported $($policies.Count) policies to $file" -ForegroundColor Green
    exit 0
}

if ($import) {
    if (-not $targetVip) { throw "targetVip is required for import." }
    if (-not $replicationTarget) { throw "replicationTarget is required for import." }
    if (-not (Test-Path $file)) { throw "File $file not found." }

    apiauth -vip $targetVip -username $username -domain $domain

    $policies = Get-Content $file | ConvertFrom-Json

    foreach ($policy in $policies) {
        # Update replication target if present
        if ($policy.replicationParams -and $policy.replicationParams.target) {
            $policy.replicationParams.target.name = $replicationTarget
        }
        # Remove IDs and cluster-specific fields to avoid conflicts
        $policy.PSObject.Properties.Remove('id')
        $policy.PSObject.Properties.Remove('clusterId')
        $policy.PSObject.Properties.Remove('clusterName')
        $policy.PSObject.Properties.Remove('creationTimeUsecs')
        $policy.PSObject.Properties.Remove('modificationTimeUsecs')

        # Create the policy on the target cluster
        try {
            api post /public/protectionPolicies $policy
            Write-Host "Imported policy: $($policy.name)" -ForegroundColor Green
        } catch {
            Write-Host "Failed to import policy: $($policy.name)" -ForegroundColor Red
            Write-Host $_.Exception.Message
        }
    }
    exit 0
}

Write-Host "Specify -export or -import. Use -? for help." -ForegroundColor Yellow
exit 1