<#
.SYNOPSIS
Exports all possible API configuration items

.NOTES
Author: Doug Austin  
Date: 2025-06-04

#>

param (
    [string]$source,
    [string[]]$target,
    [string]$username,
    [string]$domain = 'domain.com'
)

. "$PSScriptRoot\cohesity-api.ps1"

# Authenticate to source cluster
apiauth -vip $source -username $username -domain $domain

# List of API endpoints to GET
$apiEndpoints = @(
    "/appEntities",
    "/backupEntities",
    "/backupsources",
    "/datastores",
    "/entitiesOfType",
    "/networkEntities",
    "/reports/backupsources",
    "/resourcePools",
    "/virtualMachines",
    "/vmwareFolders",
    "/clientSubnetWhitelist",
    "/clusterPlatforms",
    "/clusterPublicKey",
    "/clusterStats",
    "/clusterSubnets",
    "/clusterUpgradeStatus",
    "/clusters/gflag",
    "/gandalf/listMasters",
    "/ioPreferentialTier",
    "/nfsExportPaths",
    "/ntpServers",
    "/proxyServers",
    "/public/cluster/backgroundActivitySchedule",
    "/public/cluster/keys",
    "/public/clusters/creationProgress",
    "/public/clusters/ioPreferentialTier",
    "/public/clusters/services/states",
    "/public/externalClientSubnets",
    "/snmp/mibsFile",
    "/diskStats",
    "/disks",
    "/downloadfiles",
    "/file/restoreInformation",
    "/file/stat",
    "/file/versions",
    "/linuxCommand/list",
    "/nodeStats",
    "/public/freeNodes",
    "/public/node/status",
    "/public/nodes",
    "/progressMonitors",
    "/public/statistics/entities",
    "/public/statistics/entitiesSchema",
    "/public/statistics/timeSeriesSchema",
    "/public/statistics/timeSeriesStats",
    "/public/tasks/status",
    "/stats/fileDownloads",
    "/public/activeDirectory",
    "/public/activeDirectory/centrifyZones",
    "/public/activeDirectory/domainControllers",
    "/public/activeDirectory/principals",
    "/public/alertCategories",
    "/public/alertNotificationRules",
    "/public/alertResolutions",
    "/public/alertTypes",
    "/public/alerts",
    "/public/analytics/apps",
    "/public/analytics/mappers",
    "/public/analytics/mrAppRuns",
    "/public/analytics/mrBaseJar",
    "/public/analytics/mrFileFormats",
    "/public/analytics/mrOutputfiles",
    "/public/analytics/reducers",
    "/public/analytics/supportedPatterns",
    "/public/analytics/uploadJarPath",
    "/public/antivirusGroups",
    "/public/icapConnectionStatus",
    "/public/infectedFiles",
    "/public/appInstances",
    "/public/apps",
    "/public/auditLogs/actions",
    "/public/auditLogs/categories",
    "/public/auditLogs/cluster",
    "/public/banners",
    "/public/basicClusterInfo",
    "/public/cluster",
    "/public/cluster/appSettings",
    "/public/cluster/status",
    "/public/bifrost/vlans",
    "/public/vlans",
    "/public/certificates/global",
    "/public/certificates/webServer",
    "/public/clusterPartitions",
    "/public/dashboard",
    "/public/groups",
    "/public/idps",
    "/public/interface",
    "/public/interfaceGroups",
    "/public/kmsConfig",
    "/public/kmsStatus",
    "/public/ldapProvider",
    "/public/monitoring/jobRunInfo",
    "/public/monitoring/jobs",
    "/public/monitoring/objectDetails",
    "/public/network/hosts",
    "/public/nfsConnections",
    "/public/nlmLocks",
    "/public/qosPolicies",
    "/public/shares",
    "/public/smbConnections",
    "/public/viewDirectoryQuotas",
    "/public/viewUserQuotas",
    "/public/views",
    "/public/packages",
    "/public/physicalAgents/download",
    "/public/protectionSources",
    "/public/protectionSources/applicationServers",
    "/public/protectionSources/datastores",
    "/public/protectionSources/downloadCftFile",
    "/public/protectionSources/exchangeDagHosts",
    "/public/protectionSources/objects",
    "/public/protectionSources/protectedObjects",
    "/public/protectionSources/registrationInfo",
    "/public/protectionSources/rootNodes",
    "/public/protectionSources/sqlAagHostsAndDatabases",
    "/public/protectionSources/virtualMachines",
    "/public/postgres",
    "/public/principals/protectionSources",
    "/public/principals/searchPrincipals",
    "/public/sessionUser",
    "/public/users",
    "/public/users/privileges",
    "/public/usersApiKeys",
    "/public/privileges",
    "/public/protectionJobs",
    "/public/protectionPolicies",
    "/public/protectionPolicySummary",
    "/public/protectionRuns",
    "/public/protectionRuns/errors",
    "/public/remoteClusters",
    "/public/replicationEncryptionKey",
    "/public/remoteVaults/cloudDomainMigration",
    "/public/remoteVaults/restoreTasks",
    "/public/remoteVaults/searchJobResults",
    "/public/remoteVaults/searchJobs",
    "/public/reports/agents",
    "/public/reports/cloudArchiveReport",
    "/public/reports/dataTransferFromVaults",
    "/public/reports/dataTransferToVaults",
    "/public/reports/gdpr",
    "/public/reports/protectedObjectsTrends",
    "/public/reports/protectionSourcesJobRuns",
    "/public/reports/protectionSourcesJobsSummary",
    "/public/restore/adDomainRootTopology",
    "/public/restore/adObjects",
    "/public/restore/files",
    "/public/restore/files/fstats",
    "/public/restore/files/snapshotsInformation",
    "/public/restore/objects",
    "/public/restore/office365/onedrive/documents",
    "/public/restore/office365/outlook/emails",
    "/public/restore/office365/sharepoint/documents",
    "/public/restore/tasks",
    "/public/restore/virtualDiskInformation",
    "/public/restore/vms/directoryList",
    "/public/restore/vms/volumesInformation",
    "/public/roles",
    "/public/routes",
    "/public/scheduler",
    "/public/search/protectionRuns",
    "/public/search/protectionSources",
    "/public/sessionUser/notifications",
    "/public/sessionUser/preferences",
    "/public/smbFileOpens",
    "/public/stats/alerts",
    "/public/stats/consumers",
    "/public/stats/files",
    "/public/stats/protectionRuns",
    "/public/stats/protectionRuns/lastRun",
    "/public/stats/protectionSummary",
    "/public/stats/restores",
    "/public/stats/storage",
    "/public/stats/tenants",
    "/public/stats/vaults",
    "/public/stats/vaults/providers",
    "/public/stats/vaults/runs",
    "/public/stats/viewBoxes",
    "/public/stats/views",
    "/public/stats/views/protocols",
    "/public/tenants",
    "/public/tenants/proxies",
    "/public/tenants/proxy/config",
    "/public/tenants/proxy/image",
    "/public/vaults",
    "/public/vaults/archiveMediaInfo",
    "/public/vaults/bandwidthSettings",
    "/public/viewBoxes",
    "/searchfiles",
    "/searchvms",
    "/snmp/config",
    "/vm/directoryList",
    "/vm/volumeInfo"
)

# Store results
$results = @()

foreach ($endpoint in $apiEndpoints) {
    try {
        $response = api get $endpoint
        $count = if ($response -is [System.Collections.IEnumerable] -and !$response.GetType().IsPrimitive) {
            $response.Count
        } elseif ($response) {
            1
        } else {
            0
        }
        $results += [PSCustomObject]@{
            Endpoint = $endpoint
            Status   = "Success"
            Count    = $count
        }
    } catch {
        $results += [PSCustomObject]@{
            Endpoint = $endpoint
            Status   = "Error: $_"
            Count    = 0
        }
    }
}

# Display results in a table
$results | Format-Table -AutoSize