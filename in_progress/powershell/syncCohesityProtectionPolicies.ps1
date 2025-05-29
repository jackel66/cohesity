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

.EXAMPLE
.\syncCohesityProtectionPolicies.ps1 -sourceVip cluster0 -targetVips cluster1,cluster2 -username user -domain domain.com

.EXAMPLE
.\syncCohesityProtectionPolicies.ps1 -sourceVip cluster0 -username user
(Reads targetVips from targetvips.txt)

.EXAMPLE
.\syncCohesityProtectionPolicies.ps1 -sourceVip cluster0 -targetVips cluster1 -username user -replicationTargetName newClusterName
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

# --- Connect to Source and get all protection policies ---
Write-Host "`nConnecting to source cluster: $sourceVip" -ForegroundColor Cyan
apiauth -vip $sourceVip -username $username -domain $domain

$sourcePolicies = api get /public/protectionPolicies

if (-not $sourcePolicies) {
    Write-Host "No protection policies found on source cluster." -ForegroundColor Yellow
    exit 0
}

# List of top-level properties to exclude
$excludeProps = @(
    'id', 'clusterId', 'clusterName', 'creationTimeUsecs', 'modificationTimeUsecs', 'lastModificationTimeUsecs'
)

# Helper function to recursively remove 'Id' fields from nested objects/arrays
function Remove-NestedIdFields($obj) {
    if ($null -eq $obj) { return $obj }
    if ($obj -is [System.Collections.IEnumerable] -and -not ($obj -is [string])) {
        $newArr = @()
        foreach ($item in $obj) {
            $newArr += Remove-NestedIdFields $item
        }
        return $newArr
    } elseif ($obj -is [PSCustomObject]) {
        $copy = $obj.PSObject.Copy()
        foreach ($prop in @($copy.PSObject.Properties.Name)) {
            if ([string]::IsNullOrWhiteSpace($prop)) { continue } # <-- Add this line
            if ($prop -eq 'Id' -or $prop -eq 'id') {
                $copy.PSObject.Properties.Remove($prop)
            } else {
                $copy.$prop = Remove-NestedIdFields $copy.$prop
            }
        }
        return $copy
    } else {
        return $obj
    }
}

# Ensure all 'days' properties are arrays as required by the API
function Ensure-DaysArray($schedule) {
    if ($null -eq $schedule) { return }
    if ($schedule.dailySchedule -and $schedule.dailySchedule.days) {
        if ($schedule.dailySchedule.days -isnot [System.Collections.IEnumerable] -or $schedule.dailySchedule.days -is [string]) {
            $schedule.dailySchedule.days = @($schedule.dailySchedule.days)
        }
    }
}

# --- For each target cluster, create missing or update mismatched policies ---
foreach ($targetVip in $targetVips) {
    Write-Host "`nConnecting to target cluster: $targetVip" -ForegroundColor Cyan
    apiauth -vip $targetVip -username $username -domain $domain

    $targetPolicies = api get /public/protectionPolicies
    $targetPolicyTable = @{}
    foreach ($p in $targetPolicies) {
        if ($null -ne $p.name -and $p.name -ne "") {
            $targetPolicyTable[$p.name] = $p
        }
    }

    foreach ($policy in $sourcePolicies) {
        if ($null -eq $policy.name -or $policy.name -eq "") {
            Write-Host "Skipping a policy with null or empty name." -ForegroundColor Yellow
            continue
        }
        $targetPolicy = $targetPolicyTable[$policy.name]

        # Build the body for the new/updated policy
        $body = @{}
        foreach ($prop in $policy.PSObject.Properties.Name) {
            if ($excludeProps -notcontains $prop) {
                $value = $policy.$prop
                # Remove nested Id fields from arrays/objects
                $body[$prop] = Remove-NestedIdFields $value
            }
        }

        # --- Replace replication target name if needed ---
        if ($replicationTargetName -and $body.snapshotReplicationCopyPolicies) {
            foreach ($copyPolicy in $body.snapshotReplicationCopyPolicies) {
                if ($copyPolicy.target -and $copyPolicy.target.clusterName) {
                    $copyPolicy.target.clusterName = $replicationTargetName
                }
            }
        }

        # --- Ensure snapshotReplicationCopyPolicies is always an array or $null ---
        if ($body.ContainsKey('snapshotReplicationCopyPolicies')) {
            if ($null -eq $body.snapshotReplicationCopyPolicies) {
                # leave as null
            } elseif ($body.snapshotReplicationCopyPolicies -isnot [System.Collections.IEnumerable] -or $body.snapshotReplicationCopyPolicies -is [string]) {
                $body.snapshotReplicationCopyPolicies = @($body.snapshotReplicationCopyPolicies)
            }
        }

        # Fix for fullSchedulingPolicy
        if ($body.fullSchedulingPolicy) {
            Ensure-DaysArray $body.fullSchedulingPolicy
        }
        # Fix for incrementalSchedulingPolicy
        if ($body.incrementalSchedulingPolicy) {
            Ensure-DaysArray $body.incrementalSchedulingPolicy
        }
        # Fix for logSchedulingPolicy (if it has a dailySchedule.days)
        if ($body.logSchedulingPolicy) {
            Ensure-DaysArray $body.logSchedulingPolicy
        }

        # Remove any null properties from the body
        foreach ($key in @($body.Keys)) {
            if ($null -eq $body[$key]) {
                $body.Remove($key)
            }
        }

        # If policy exists, compare and update if needed
        if ($targetPolicy) {
            $srcJson = $body | ConvertTo-Json -Depth 10
            $tgtJson = $targetPolicy | ConvertTo-Json -Depth 10
            if ($srcJson -ne $tgtJson) {
                try {
                    api put "/public/protectionPolicies/$($targetPolicy.id)" $body
                    Write-Host "Updated policy '$($policy.name)' on $targetVip." -ForegroundColor Cyan
                } catch {
                    Write-Host "Failed to update policy '$($policy.name)' on $targetVip." -ForegroundColor Red
                    Write-Host $_.Exception.Message
                }
            } else {
                Write-Host "Policy '$($policy.name)' already in sync on $targetVip." -ForegroundColor Green
            }
        } else {
            try {
                api post /public/protectionPolicies $body
                Write-Host "Created policy '$($policy.name)' on $targetVip." -ForegroundColor Green
            } catch {
                Write-Host "Failed to create policy '$($policy.name)' on $targetVip." -ForegroundColor Red
                Write-Host $_.Exception.Message
            }
        }
    }

    if (Get-Command -Name apidrop -ErrorAction SilentlyContinue) {
        apidrop
    }

    Write-Host "Protection policy synchronization complete for $targetVip." -ForegroundColor DarkGreen -BackgroundColor Green
}