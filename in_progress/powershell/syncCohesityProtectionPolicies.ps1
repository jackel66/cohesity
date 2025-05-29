
<#
.SYNOPSIS
Syncs Cohesity protection policies from a source cluster to one or more target clusters.

.PARAMETER sourceVip
FQDN or IP of the source Cohesity cluster.

.PARAMETER targetVips
One or more target Cohesity VIPs. Can be passed via parameter or via targetvips.txt.

.PARAMETER username
Username with API access.

.PARAMETER domain
Domain of the username (e.g., domain.com or LOCAL). Defaults to domain.com.

.PARAMETER replicationTargetName
Optional name of the replication target cluster to replace in snapshot replication copy policies.
#>

param (
    [string]$sourceVip,
    [string[]]$targetVips,
    [string]$username,
    [string]$domain = 'domain.com',
    [string]$replicationTargetName
)

if (-not $targetVips) {
    $filePath = "$PSScriptRoot\targetvips_policies.txt"
    if (Test-Path $filePath) {
        $targetVips = Get-Content $filePath | Where-Object { $_ -and $_.Trim() -ne "" }
        Write-Host "Loaded $($targetVips.Count) targets from targetvips.txt" -ForegroundColor Cyan
    } else {
        Write-Host "No targetVips provided and targetvips.txt not found." -ForegroundColor Red
        exit 1
    }
}

. "$PSScriptRoot\cohesity-api.ps1"

Write-Host "`nConnecting to source cluster: $sourceVip" -ForegroundColor Cyan
apiauth -vip $sourceVip -username $username -domain $domain

$sourcePolicies = api get /public/protectionPolicies

if (-not $sourcePolicies) {
    Write-Host "No protection policies found on source cluster." -ForegroundColor Yellow
    exit 0
}

$excludeProps = @('id', 'clusterId', 'clusterName', 'creationTimeUsecs', 'modificationTimeUsecs', 'lastModificationTimeUsecs')

function Remove-NestedIdFields($obj) {
    if ($null -eq $obj) { return $obj }
    if ($obj -is [System.Collections.IEnumerable] -and -not ($obj -is [string])) {
        $newArr = @()
        foreach ($item in $obj) {
            $newArr += Remove-NestedIdFields $item
        }
        return $newArr
    } elseif ($obj -is [PSCustomObject]) {
        $copy = [PSCustomObject]@{}
        foreach ($prop in $obj.PSObject.Properties) {
            if ($prop.Name -match '^(id|Id)$') { continue }
            try {
                $copy | Add-Member -MemberType NoteProperty -Name $prop.Name -Value (Remove-NestedIdFields $prop.Value)
            } catch {
                # Skip read-only or problematic properties
            }
        }
        return $copy
    }
    return $obj
}

function Ensure-DaysArray($schedule) {
    if ($null -eq $schedule) { return }
    if ($schedule.dailySchedule -and $schedule.dailySchedule.days) {
        if ($schedule.dailySchedule.days -isnot [System.Collections.IEnumerable] -or $schedule.dailySchedule.days -is [string]) {
            $schedule.dailySchedule.days = @($schedule.dailySchedule.days)
        }
    }
}

foreach ($targetVip in $targetVips) {
    Write-Host "`nConnecting to target cluster: $targetVip" -ForegroundColor Cyan
    apiauth -vip $targetVip -username $username -domain $domain

    $targetPolicies = api get /public/protectionPolicies
    $targetPolicyTable = @{}
    foreach ($p in $targetPolicies) {
        if ($p.name) {
            $targetPolicyTable[$p.name] = $p
        }
    }

    $remoteClusters = api get /public/remoteClusters
    $targetClusterObj = $null
    $clusterId = $null
    $clusterName = $null

    if ($replicationTargetName) {
        $targetClusterObj = $remoteClusters | Where-Object { $_.name -eq $replicationTargetName }
        if (-not $targetClusterObj) {
            Write-Host "Replication target '$replicationTargetName' not found in remote clusters for $targetVip." -ForegroundColor Red
            continue
        }
        $clusterId = [int64]$targetClusterObj.clusterid
        $clusterName = $targetClusterObj.name
    }

    foreach ($policy in $sourcePolicies) {
        if (-not $policy.name) {
            Write-Host "Skipping a policy with null or empty name." -ForegroundColor Yellow
            continue
        }
        $targetPolicy = $targetPolicyTable[$policy.name]

        $body = @{}
        foreach ($prop in $policy.PSObject.Properties.Name) {
            if ($excludeProps -notcontains $prop) {
                $body[$prop] = Remove-NestedIdFields $policy.$prop
            }
        }

        if ($replicationTargetName -and $body.snapshotReplicationCopyPolicies) {
            if ($body.snapshotReplicationCopyPolicies -isnot [System.Collections.IEnumerable] -or $body.snapshotReplicationCopyPolicies -is [string]) {
                $body.snapshotReplicationCopyPolicies = @($body.snapshotReplicationCopyPolicies)
            }

            for ($i = 0; $i -lt $body.snapshotReplicationCopyPolicies.Count; $i++) {
                $body.snapshotReplicationCopyPolicies[$i].target = @{
                    clusterId = $clusterId
                    clusterName = $clusterName
                }
            }
        }

        if ($body.fullSchedulingPolicy) { Ensure-DaysArray $body.fullSchedulingPolicy }
        if ($body.incrementalSchedulingPolicy) { Ensure-DaysArray $body.incrementalSchedulingPolicy }
        if ($body.logSchedulingPolicy) { Ensure-DaysArray $body.logSchedulingPolicy }

        foreach ($key in @($body.Keys)) {
            if ($null -eq $body[$key]) {
                $body.Remove($key)
            }
        }

        try {
            if ($targetPolicy) {
                
function Normalize-JsonObject($obj) {
    return ($obj | ConvertTo-Json -Depth 10 -Compress | ConvertFrom-Json)
}

$normalizedSrc = Normalize-JsonObject $body
$normalizedTgt = Normalize-JsonObject $targetPolicy

if ($null -eq $normalizedTgt -or ($normalizedSrc | ConvertTo-Json -Depth 10 -Compress) -ne ($normalizedTgt | ConvertTo-Json -Depth 10 -Compress)) {

                    api put "/public/protectionPolicies/$($targetPolicy.id)" $body
                    Write-Host "Updated policy '$($policy.name)' on $targetVip." -ForegroundColor Cyan
                } else {
                    Write-Host "Policy '$($policy.name)' already in sync on $targetVip." -ForegroundColor Green
                }
            } else {
                api post /public/protectionPolicies $body
                Write-Host "Created policy '$($policy.name)' on $targetVip." -ForegroundColor Green
            }
        } catch {
            Write-Host "Failed to apply policy '$($policy.name)' on $targetVip." -ForegroundColor Red
            Write-Host $_.Exception.Message
        }
    }

    if (Get-Command -Name apidrop -ErrorAction SilentlyContinue) {
        apidrop
    }

    Write-Host "Protection policy synchronization complete for $targetVip." -ForegroundColor DarkGreen -BackgroundColor Green
}
