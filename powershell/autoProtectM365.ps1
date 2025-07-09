<#
.SYNOPSIS
    Cohesity M365 Backup Automation Script with DryRun Mode Support
 
.DESCRIPTION
    This script automates M365 backup operations across multiple Cohesity clusters.
    It can run in normal production mode or test mode for one-off operations against any cluster.
 
.PARAMETER username
    Username for Cohesity authentication
 
.PARAMETER password
    Base64 encoded password for Cohesity authentication
 
.PARAMETER testVip
    VIP/FQDN of test cluster (enables test mode)
 
.PARAMETER testClusterName
    Display name for test cluster (optional)
 
.PARAMETER testObjectType
    Specific object type to test (mailbox, onedrive, sites, teams, publicfolders)
 
.PARAMETER testJobPrefix
    Job prefix to use for test operations
 
.PARAMETER dryRun
    Run in dry-run mode - no actual changes will be made
 
.PARAMETER testMode
    Enable test mode (automatically enabled when testVip is provided)
 
.PARAMETER ignoreSafetyLimit
    Bypass the safety limit that prevents adding too many objects at once (use with caution)
 
.PARAMETER showDiscovery
    Show detailed cluster discovery information (policies, storage domains, existing jobs)
 
.PARAMETER createFirstJob
    Create the first protection job if none exist with the specified prefix
 
.PARAMETER firstJobNum
    Job number for the first job when using -createFirstJob (default: 001)
 
.PARAMETER disableIndexing
    Disable indexing for new protection jobs
 
.PARAMETER fullSlaMinutes
    SLA minutes for full backups (default: 1440)
 
.PARAMETER incrementalSlaMinutes
    SLA minutes for incremental backups (default: 720)
 
.PARAMETER startTime
    Job start time in HH:MM format (default: 16:00)
 
.PARAMETER timeZone
    Time zone for job scheduling (default: America/Los_Angeles)
 
.PARAMETER apiTimeoutSeconds
    Timeout in seconds for API calls (default: 60)
 
.PARAMETER letterRange
    Filter objects by letter range (e.g., "A-M", "N-Z", "A-F", "G-M"). Only objects whose names start with letters in the specified range will be processed. Useful for batch processing large environments.
 
.PARAMETER fillAllGroups
    Fill existing protection groups with available capacity before creating new ones. By default, only the most recent group is filled to capacity before creating new groups.
 
.EXAMPLE
    # Normal production run
    .\autoprotecto365-new.ps1 -username "myuser" -password "password"
 
.EXAMPLE
    # Dry run against test cluster - discovery only
    .\autoprotecto365-new.ps1 -username "myuser" -password "password" -testVip "test-cohesity.company.com" -dryRun
 
.EXAMPLE
    # Process only objects starting with letters A through M
    .\autoprotecto365-new.ps1 -username "myuser" -password "password" -letterRange "A-M" -dryRun
 
.EXAMPLE
    # Fill all existing protection groups before creating new ones
    .\autoprotecto365-new.ps1 -username "myuser" -password "password" -fillAllGroups -dryRun
 
.EXAMPLE
    # Show cluster discovery information
    .\autoprotecto365-new.ps1 -username "myuser" -password "password" -testVip "test-cohesity.company.com" -showDiscovery -dryRun
 
.EXAMPLE
    # Test specific object type against test cluster
    .\autoprotecto365-new.ps1 -username "myuser" -password "password" -testVip "test-cohesity.company.com" -testObjectType "mailbox" -testJobPrefix "TEST-Exchange-" -dryRun
 
.EXAMPLE
    # Live test against test cluster (will make actual changes)
    .\autoprotecto365-new.ps1 -username "myuser" -password "password" -testVip "test-cohesity.company.com" -testObjectType "onedrive" -testJobPrefix "TEST-OneDrive-"
 
.EXAMPLE
    # Bypass safety limits for large migrations (use with caution)
    .\autoprotecto365-new.ps1 -username "myuser" -password "password" -ignoreSafetyLimit
 
.EXAMPLE
    # Create first job with custom settings
    .\autoprotecto365-new.ps1 -username "myuser" -password "password" -testVip "test-cluster.com" -testJobPrefix "MyExchange-" -testObjectType "mailbox" -createFirstJob -firstJobNum "01" -startTime "18:00" -disableIndexing
 
.EXAMPLE
    # Create job with custom SLA and time zone
    .\autoprotecto365-new.ps1 -username "myuser" -password "password" -testVip "test-cluster.com" -testJobPrefix "OneDrive-" -testObjectType "onedrive" -createFirstJob -fullSlaMinutes 2880 -incrementalSlaMinutes 1440 -timeZone "America/New_York"
 
.EXAMPLE
    # Use custom API timeout for slow networks
    .\autoprotecto365-new.ps1 -username "myuser" -password "password" -testVip "remote-cluster.com" -apiTimeoutSeconds 120 -dryRun
 
.NOTES
    Test Mode Features:
    - Connect to any Cohesity cluster
    - Discovery mode shows cluster information, policies, storage domains
    - Dry run mode shows what would be done without making changes
    - Can test specific object types or all types
    - Detailed logging and progress reporting
   
    Safety Features:
    - Configurable limits prevent accidental mass additions
    - Default limit: 500 total objects per run, 250 per object type
    - Limits can be adjusted in script configuration section
    - Use -ignoreSafetyLimit to bypass (use with extreme caution)
    - Safety checks are skipped in dry run mode
   
#>
 
Param (
    [string]$username,
    [string]$password, # Base64 encoded password (optional - will use cached credentials if not provided)
    [string]$testVip, # VIP/FQDN of test cluster (enables test mode)    [string]$testClusterName, # Display name for test cluster (optional)
    [string]$testObjectType, # Specific object type to test (mailbox, onedrive, sites, teams, publicfolders)
    [string]$testJobPrefix, # Job prefix to use for test operations
    [switch]$dryRun, # Run in dry-run mode - no actual changes will be made
    [switch]$testMode, # Enable test mode (automatically enabled when testVip is provided)
    [switch]$ignoreSafetyLimit, # Bypass the safety limit that prevents adding too many objects at once (use with caution)
    [switch]$showDiscovery, # Show detailed cluster discovery information (policies, storage domains, existing jobs)
    [switch]$createFirstJob, # Create the first protection job if none exist with the specified prefix
    [string]$firstJobNum = '001', # Job number for the first job when using -createFirstJob (default: 001)
    [switch]$disableIndexing, # Disable indexing for new protection jobs
    [int]$fullSlaMinutes = 1440, # SLA minutes for full backups (default: 1440)
    [int]$incrementalSlaMinutes = 720, # SLA minutes for incremental backups (default: 720)
    [string]$startTime = '16:00', # Job start time in HH:MM format (default: 16:00)   
    [string]$timeZone = 'America/Los_Angeles',
    [int]$apiTimeoutSeconds = 300, # Timeout in seconds for API calls (default: 300)
    [string]$letterRange = $null, # Filter objects by letter range (e.g., "A-M", "N-Z", "A-F", "G-M", etc.)
    [switch]$fillAllGroups # Fill existing protection groups with available capacity before creating new ones
)
 
# ==============================================================================
# Common Constants
$domain = "domain.com" # Domain for Cohesity authentication
$sourceName = "m365.com" # O365 source name to use for discovery and operations
$policyName = "Site_PROD_M365" # Default policy name for new jobs (Site_PROD_M365 for PROD, SNOT_Test_M365 for SNOT)
$maxObjectsPerJob = 500 # Maximum objects to add per protection job (default: 500)
 
# Safety Configuration - prevents accidental mass additions
$maxObjectsToAddPerRun = 1000  # Maximum total objects to add in a single script run
$maxObjectsToAddPerObjectType = 500  # Maximum objects to add per object type (mailbox, onedrive, etc.)
# ==============================================================================
 
 
# Cluster configuration - centralized for easier management
$clusters = @(
    @{
        Name = "Cluster A"
        VIP = "ClusterA.domain.com"
        Tasks = @(
            @{
                JobPrefix = 'Exchange-Prefix'
                ObjectType = 'mailbox'
                Description = "Exchange"
            }
        )
    },
    @{
        Name = "Cluster B"
        VIP = "ClusterB.domain.com"
        Tasks = @(
            @{
                JobPrefix = 'OneDrive-Prefix'
                ObjectType = 'onedrive'
                Description = "OneDrive"
            },
            @{
                JobPrefix = 'Teams-Prefix'
                ObjectType = 'teams'
                Description = "Teams"
            }
        )
    },
    @{
        Name = "Cluster C"
        VIP = "ClusterC.domain.com"
        Tasks = @(
            @{
                JobPrefix = 'SharePoint-Prefix'
                ObjectType = 'sites'
                Description = "SharePoint"
            }
        )
    }
)
 
# --------- Script Functions ---------
# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)
 
# Configure API timeout
if ($apiTimeoutSeconds -gt 0) {
    Write-Host "Setting API timeout to $apiTimeoutSeconds seconds" -ForegroundColor Cyan
    $Global:TIMEOUT_SECONDS = $apiTimeoutSeconds
    # Set PowerShell web request timeout if the variable exists
    if (Get-Variable -Name "PSDefaultParameterValues" -ErrorAction SilentlyContinue) {
        $PSDefaultParameterValues['Invoke-RestMethod:TimeoutSec'] = $apiTimeoutSeconds
        $PSDefaultParameterValues['Invoke-WebRequest:TimeoutSec'] = $apiTimeoutSeconds
    }
}
 
# Decode credentials
$arg_username = $username.split('@')[0]
$arg_password = [Text.Encoding]::Utf8.GetString([Convert]::FromBase64String($password))
 
# Generate log file path based on current date and time
$logFileName = "autoprotect-o365-$(Get-Date -Format 'yyyy-MM-dd').log"
$script:logFilePath = Join-Path -Path $PSScriptRoot -ChildPath $logFileName
 
# Ensure log directory exists and log file is accessible
try {
    if (-not (Test-Path $PSScriptRoot)) {
        New-Item -ItemType Directory -Path $PSScriptRoot -Force | Out-Null
    }
   
    # Ensure the log file path is not null or empty
    if (-not $script:logFilePath -or $script:logFilePath.Trim() -eq "") {
        throw "Log file path is null or empty"
    }
   
    # Test write access by attempting to create/append to the log file
    "Script started at $(Get-Date)" | Add-Content -Path $script:logFilePath -Encoding UTF8 -ErrorAction Stop
    Write-Host "Logging to: $($script:logFilePath)" -ForegroundColor Cyan
} catch {
    Write-Warning "Could not initialize log file at $($script:logFilePath): $($_.Exception.Message)"
    $script:logFilePath = $null
}
 
# Helper function to safely write to log file
function Write-SafeLog {
    param(
        [string]$Message
    )
   
    try {
        # Multiple checks to ensure we have a valid log file path
        if (-not $script:logFilePath) {
            # Debug info for troubleshooting
            Write-Host "[DEBUG] Write-SafeLog: logFilePath is null" -ForegroundColor Yellow
            return
        }
       
        if ($script:logFilePath.Trim() -eq "") {
            # Debug info for troubleshooting 
            Write-Host "[DEBUG] Write-SafeLog: logFilePath is empty string" -ForegroundColor Yellow
            return
        }
       
        $parentPath = Split-Path $script:logFilePath -Parent
        if (-not (Test-Path $parentPath)) {
            # Debug info for troubleshooting
            Write-Host "[DEBUG] Write-SafeLog: Parent directory does not exist: $parentPath" -ForegroundColor Yellow
            return
        }
       
        Add-Content -Path $script:logFilePath -Value $Message -Encoding UTF8 -ErrorAction Stop
    }
    catch {
        # Output debug information to help track down the issue
        Write-Host "[DEBUG] Write-SafeLog failed: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "[DEBUG] LogFilePath value: '$($script:logFilePath)'" -ForegroundColor Red
    }
}
 
function Write-ObjectLog {
    param(
        [string]$Operation,  # "ADDED" or "REMOVED"
        [string]$ObjectId,
        [string]$ObjectName,
        [string]$JobName,
        [string]$PolicyName,
        [string]$ClusterName
    )
   
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "$timestamp | $Operation | Cluster: $ClusterName | Job: $JobName | Policy: $PolicyName | Object: $ObjectName (ID: $ObjectId)"
   
    Write-SafeLog -Message $logEntry
}
 
# Function to log capacity analysis to file
function Write-CapacityLog {
    param(
        [string]$ClusterName,
        [string]$ObjectType,
        [array]$Jobs,
        [int]$MaxObjectsPerJob,
        [int]$TotalObjects,
        [int]$ProtectedObjects,
        [int]$UnprotectedObjects
    )
   
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $summaryEntry = "$timestamp | CAPACITY_SUMMARY | Cluster: $ClusterName | ObjectType: $ObjectType | Total: $TotalObjects | Protected: $ProtectedObjects | Unprotected: $UnprotectedObjects | Jobs: $($Jobs.Count)"
   
    Write-SafeLog -Message $summaryEntry
   
    # Log individual job capacities
    foreach ($job in $Jobs) {
        $capacity = $MaxObjectsPerJob - $job.office365Params.objects.Count
        $utilizationPercent = [math]::Round(($job.office365Params.objects.Count / $MaxObjectsPerJob) * 100, 1)
        $capacityEntry = "$timestamp | CAPACITY_DETAIL | Cluster: $ClusterName | Job: $($job.name) | Objects: $($job.office365Params.objects.Count)/$MaxObjectsPerJob | Utilization: $utilizationPercent% | Available: $capacity"
        Write-SafeLog -Message $capacityEntry
    }
}
 
# Function to parse letter range and validate object names
function Test-ObjectInLetterRange {
    param(
        [string]$ObjectName,
        [string]$LetterRange
    )
   
    if (-not $LetterRange) {
        return $true  # No filter, include all objects
    }
   
    # Parse the letter range (e.g., "A-M", "N-Z", "A-F")
    if ($LetterRange -match '^([A-Za-z])-([A-Za-z])$') {
        $startLetter = $matches[1].ToUpper()
        $endLetter = $matches[2].ToUpper()
       
        # Get the first character of the object name and convert to uppercase
        $firstChar = $ObjectName.Substring(0,1).ToUpper()
       
        # Check if the first character falls within the range
        return ($firstChar -ge $startLetter -and $firstChar -le $endLetter)
    }
    else {
        Write-Warning "Invalid letter range format: '$LetterRange'. Expected format: 'A-M', 'N-Z', etc."
        return $true  # Invalid format, include all objects
    }
}
 
# Function to log skipped objects due to letter range filtering
function Write-SkippedObjectLog {
    param(
        [string]$ClusterName,
        [string]$ObjectType,
        [string]$ObjectId,
        [string]$ObjectName,
        [string]$LetterRange,
        [string]$Reason
    )
   
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "$timestamp | SKIPPED | Cluster: $ClusterName | ObjectType: $ObjectType | Object: $ObjectName (ID: $ObjectId) | Reason: $Reason | LetterRange: $LetterRange"
   
    Write-SafeLog -Message $logEntry
}
 
# Auto-enable test mode if testVip is provided
if ($testVip) {
    $testMode = $true
}
 
# Validate letter range format if provided
if ($letterRange) {
    if ($letterRange -match '^([A-Za-z])-([A-Za-z])$') {
        $startLetter = $matches[1].ToUpper()
        $endLetter = $matches[2].ToUpper()
        Write-Host "Letter Range Filter: Processing objects starting with letters $startLetter through $endLetter" -ForegroundColor Cyan
    } else {
        Write-Host "ERROR: Invalid letter range format '$letterRange'. Expected format: 'A-M', 'N-Z', etc." -ForegroundColor Red
        exit 1
    }
}
 
# Check if running in test mode against a single cluster
if ($testMode -and $testVip) {
    Write-Host "Running against TEST CLUSTER: $testVip" -ForegroundColor Magenta
    if ($dryRun) {
        Write-Host "DRY RUN MODE: No changes will be made" -ForegroundColor Yellow
    } else {
        Write-Host "LIVE MODE: Changes will be made to the test cluster" -ForegroundColor Green
    }
    Write-Host "================================================"
   
    # Create test cluster configuration
    $testCluster = @{
        Name = if ($testClusterName) { $testClusterName } else { "Test-Cluster" }
        VIP = $testVip
        Tasks = @()
    }
      # Add test task if specified
    if ($testObjectType -and $testJobPrefix) {
        $testCluster.Tasks = @(@{
            JobPrefix = $testJobPrefix
            ObjectType = $testObjectType
            Description = "Test-$testObjectType"
        })
    } else {
        # Default to all object types for discovery
        $testCluster.Tasks = @(
            @{ JobPrefix = 'Test-Exchange-'; ObjectType = 'mailbox'; Description = "Test Exchange" },
            @{ JobPrefix = 'Test-OneDrive-'; ObjectType = 'onedrive'; Description = "Test OneDrive" },
            @{ JobPrefix = 'Test-Teams-'; ObjectType = 'teams'; Description = "Test Teams" },
            @{ JobPrefix = 'Test-SharePoint-'; ObjectType = 'sites'; Description = "Test SharePoint" }
        )
    }
   
    # Override clusters array with test configuration
    $clusters = @($testCluster)
} else {
    Write-Host "Starting Cohesity O365 Backup Automation" -ForegroundColor Green
    Write-Host "================================================"
}
 
# API wrapper with timeout handling
function Invoke-ApiWithTimeout {
    param(
        [string]$Method = "get",
        [string]$Uri,
        [object]$Body = $null,
        [int]$TimeoutSeconds = $apiTimeoutSeconds,
        [int]$MaxRetries = 3,
        [string]$Description = "API call"
    )
   
    $attempt = 0
    $lastError = $null
   
    while ($attempt -lt $MaxRetries) {
        $attempt++
        try {
            Write-Verbose "$Description (attempt $attempt/$MaxRetries)"
           
            if ($Method -eq "get") {
                return api get $Uri
            } elseif ($Method -eq "post") {
                return api post $Uri $Body
            } elseif ($Method -eq "put") {
                return api put $Uri $Body
            } else {
                throw "Unsupported HTTP method: $Method"
            }
        }
        catch [System.Net.WebException] {
            $lastError = $_
            if ($_.Exception.Status -eq [System.Net.WebExceptionStatus]::Timeout) {
                Write-Warning "$Description timed out after $TimeoutSeconds seconds (attempt $attempt/$MaxRetries)"
                if ($attempt -eq $MaxRetries) {
                    throw "API call failed after $MaxRetries timeout attempts: $($_.Exception.Message)"
                }
                Start-Sleep -Seconds (2 * $attempt)  # Exponential backoff
            } else {
                throw  # Re-throw non-timeout exceptions immediately
            }
        }
        catch {
            $lastError = $_
            Write-Warning "$Description failed (attempt $attempt/$MaxRetries): $($_.Exception.Message)"
            if ($attempt -eq $MaxRetries) {
                throw "API call failed after $MaxRetries attempts: $($_.Exception.Message)"
            }
            Start-Sleep -Seconds $attempt  # Linear backoff for other errors
        }
    }
   
    throw $lastError
}
 
# Main processing function for each cluster
function Process-Cluster {
    param(
        [hashtable]$ClusterConfig,
        [string]$Username,
        [string]$Password,
        [string]$Domain,
        [switch]$DryRun = $false
    )
      Write-Host "`nProcessing cluster: $($ClusterConfig.Name)" -ForegroundColor Yellow
    Write-Host "  Cluster VIP: $($ClusterConfig.VIP)" -ForegroundColor Gray
    Write-Host "  Task count: $($ClusterConfig.Tasks.Count)" -ForegroundColor Gray
    if ($DryRun) {
        Write-Host "  DRY RUN MODE - No changes will be made" -ForegroundColor Yellow
    }    # Authenticate to cluster
    try {
        Write-Host "  Authenticating to $($ClusterConfig.VIP)..." -ForegroundColor Cyan
       
        # Use Cohesity API authentication with optional password
        # If no password provided, the API will attempt to use cached credentials
        if ($Password) {
            apiauth -vip $ClusterConfig.VIP -username $Username -password $Password -domain $Domain
        } else {
            # Let Cohesity API handle cached credentials or prompt if needed
            apiauth -vip $ClusterConfig.VIP -username $Username -domain $Domain
        }
       
        if (-not $cohesity_api.authorized) {
            Write-Host "  AUTHENTICATION FAILED - Could not authenticate to $($ClusterConfig.VIP)" -ForegroundColor Red
            Write-Host "  Possible causes:" -ForegroundColor Yellow
            Write-Host "    - Invalid or expired credentials" -ForegroundColor Yellow
            Write-Host "    - No cached credentials available (provide -password parameter)" -ForegroundColor Yellow
            Write-Host "    - Network connectivity issues" -ForegroundColor Yellow
            Write-Host "    - Cluster unavailability" -ForegroundColor Yellow
            Write-Host "  Skipping this cluster and continuing..." -ForegroundColor Yellow
            return
        }
    }
    catch {
        Write-Host "  AUTHENTICATION ERROR - $($_.Exception.Message)" -ForegroundColor Red
        if ($_.Exception.Message -like "*timeout*" -or $_.Exception.Message -like "*network*") {
            Write-Host "  This appears to be a network connectivity or timeout issue" -ForegroundColor Yellow
            Write-Host "  Consider increasing -apiTimeoutSeconds parameter or checking network connectivity" -ForegroundColor Yellow
        } elseif ($_.Exception.Message -like "*password*") {
            Write-Host "  Password-related error. Try providing explicit -password parameter" -ForegroundColor Yellow
        }
        Write-Host "  Skipping this cluster and continuing..." -ForegroundColor Yellow
        return
    }
      # Get cluster info once
    try {
        $cluster = Invoke-ApiWithTimeout -Method "get" -Uri "cluster" -Description "Getting cluster information"
        Write-Host "Connected to $($cluster.name) (version $($cluster.clusterSoftwareVersion))"
    }
    catch {
        Write-Host "  ERROR - Failed to retrieve cluster information: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "  Skipping this cluster and continuing..." -ForegroundColor Yellow
        return
    }# Cache common data to reduce API calls
    $clusterCache = Initialize-ClusterCache -SourceName $sourceName -Cluster $cluster
    if (-not $clusterCache) {
        Write-Host "  CRITICAL ERROR - Cache initialization failed for $($ClusterConfig.Name)" -ForegroundColor Red
        Write-Host "  This typically indicates:" -ForegroundColor Yellow
        Write-Host "    - Source name '$sourceName' not found on this cluster" -ForegroundColor Yellow
        Write-Host "    - Network connectivity issues" -ForegroundColor Yellow
        Write-Host "    - API timeout or cluster unavailability" -ForegroundColor Yellow
        Write-Host "  Skipping this cluster and continuing..." -ForegroundColor Yellow
        return
    }# Show discovery information if requested
    if ($showDiscovery) {
        Show-ClusterDiscovery -ClusterCache $clusterCache
    }
      # Perform safety check before processing (unless in dry run mode)
    if (-not $DryRun) {
        $safetyCheckPassed = Test-SafetyLimits -ClusterCache $clusterCache -Tasks $ClusterConfig.Tasks -MaxObjectsPerRun $maxObjectsToAddPerRun -MaxObjectsPerType $maxObjectsToAddPerObjectType -IgnoreSafetyLimit:$ignoreSafetyLimit
        if (-not $safetyCheckPassed) {
            Write-Host "  SAFETY CHECK FAILED - Skipping cluster processing for $($ClusterConfig.Name)" -ForegroundColor Red
            Write-Host "  Use -dryRun to see what would be added, or -ignoreSafetyLimit to bypass" -ForegroundColor Yellow
            return
        }
    }    # Process cleanup and protection tasks for this cluster
    foreach ($task in $ClusterConfig.Tasks) {
        $taskId = "$($ClusterConfig.Name)-$($task.ObjectType)-$((Get-Date).ToString('HH:mm:ss.fff'))"
        Write-Host "`n  Processing $($task.Description)... [TaskID: $taskId]" -ForegroundColor Cyan
        Write-Host "    Working with protection groups matching prefix: '$($task.JobPrefix)'" -ForegroundColor Gray
          # Cleanup missing objects
        $cleanupResult = Remove-MissingO365Objects -ClusterCache $clusterCache -ObjectType $task.ObjectType -DryRun:$DryRun
        if ($DryRun) {
            Write-Host "    Cleanup: $($cleanupResult.RemovedCount) objects would be removed from protection groups" -ForegroundColor Yellow
        } else {
            Write-Host "    Cleanup: $($cleanupResult.RemovedCount) objects removed from protection groups" -ForegroundColor White
            if ($cleanupResult.SkippedJobs -and $cleanupResult.SkippedJobs.Count -gt 0) {
                Write-Host "    Note: $($cleanupResult.SkippedJobs.Count) job(s) skipped due to empty objects array: $($cleanupResult.SkippedJobs -join ', ')" -ForegroundColor Cyan
            }
        }        # Auto-protect new objects
        #Write-Host "    Starting protection phase..." -ForegroundColor DarkGray
        $protectionResult = Add-NewO365Objects -ClusterCache $clusterCache -Task $task -PolicyName $policyName -MaxObjectsPerJob $maxObjectsPerJob -LetterRange $letterRange -FillAllGroups:$fillAllGroups -DryRun:$DryRun
        #Write-Host "    Protection phase completed." -ForegroundColor DarkGray
        if ($DryRun) {
            Write-Host "    Protection: $($protectionResult.AddedCount) new objects would be protected" -ForegroundColor Yellow
        } else {
            Write-Host "    Protection: $($protectionResult.AddedCount) new objects protected" -ForegroundColor Green
        }
    }
}
 
# Initialize cluster cache to reduce redundant API calls
function Initialize-ClusterCache {
    param(
        [string]$SourceName,
        [object]$Cluster
    )
   
    try {
        Write-Host "    Validating O365 source: $SourceName" -ForegroundColor Cyan
       
        # Get protection source once with timeout handling
        $rootSource = $null
        try {
            $rootSources = Invoke-ApiWithTimeout -Method "get" -Uri "protectionSources/rootNodes?environments=kO365" -Description "Getting O365 root sources"
            $rootSource = $rootSources | Where-Object {$_.protectionSource.name -eq $SourceName}
        }
        catch {
            Write-Host "    ERROR: Failed to retrieve protection sources - $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "    This could indicate network connectivity issues or cluster unavailability" -ForegroundColor Yellow
            return $null
        }
       
        if (-not $rootSource) {
            Write-Host "    ERROR: Protection source '$SourceName' not found" -ForegroundColor Red
            Write-Host "    Available O365 sources on this cluster:" -ForegroundColor Yellow
            try {
                $allSources = Invoke-ApiWithTimeout -Method "get" -Uri "protectionSources/rootNodes?environments=kO365" -Description "Listing available sources"
                if ($allSources) {
                    foreach ($src in $allSources) {
                        Write-Host "      - $($src.protectionSource.name)" -ForegroundColor Yellow
                    }
                } else {
                    Write-Host "      - No O365 sources found" -ForegroundColor Yellow
                }
            }
            catch {
                Write-Host "      - Unable to list sources due to error: $($_.Exception.Message)" -ForegroundColor Red
            }
            return $null
        }
       
        Write-Host "    Source validation successful" -ForegroundColor Green
        Write-Host "      Root source ID: $($rootSource.protectionSource.id)" -ForegroundColor Cyan
       
        # Determine entity types based on cluster version
        $entityTypes = if ($Cluster.clusterSoftwareVersion -lt '6.6') {
            'kMailbox,kUser,kGroup,kSite,kPublicFolder'
        } else {
            'kMailbox,kUser,kGroup,kSite,kPublicFolder,kO365Exchange,kO365OneDrive,kO365Sharepoint'
        }        Write-Host "    Loading source structure and protection groups..." -ForegroundColor Cyan
       
        # Get source structure once with timeout handling
        Write-Progress -Activity "Initializing Cluster Cache" -Status "Loading source structure..." -PercentComplete 50
        try {
            $source = Invoke-ApiWithTimeout -Method "get" -Uri "protectionSources?id=$($rootSource.protectionSource.id)&excludeOffice365Types=$entityTypes&allUnderHierarchy=false" -Description "Getting source structure"
            Write-Host "      Source structure loaded successfully" -ForegroundColor Green
        }
        catch {
            Write-Host "      ERROR: Failed to load source structure - $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "      API URI: protectionSources?id=$($rootSource.protectionSource.id)&excludeOffice365Types=$entityTypes&allUnderHierarchy=false" -ForegroundColor Yellow
            throw
        }
          # Get all protection groups using the proven approach from autoprotectO365.ps1
        Write-Progress -Activity "Initializing Cluster Cache" -Status "Loading protection groups..." -PercentComplete 75
        try {
            Write-Host "      Loading O365 protection groups..." -ForegroundColor Cyan
            $protectionGroupsResult = api get -v2 "data-protect/protection-groups?environments=kO365&isActive=true&isDeleted=false"
            if ($protectionGroupsResult -and $protectionGroupsResult.protectionGroups) {
                $protectionGroups = $protectionGroupsResult.protectionGroups
                Write-Host "      Found $($protectionGroups.Count) active O365 protection groups" -ForegroundColor Green
            } else {
                Write-Host "      No O365 protection groups found" -ForegroundColor Yellow
                $protectionGroups = @()
            }
        }
        catch {
            Write-Host "      Failed to load protection groups: $($_.Exception.Message)" -ForegroundColor Red
            $protectionGroups = @()
        }
       
        Write-Progress -Activity "Initializing Cluster Cache" -Completed
        Write-Host "    Cache initialization completed successfully" -ForegroundColor Green
       
        return @{
            RootSource = $rootSource
            Source = $source
            ProtectionGroups = $protectionGroups
            EntityTypes = $entityTypes
            Cluster = $Cluster
        }
    }
    catch {
        Write-Host "    ERROR: Failed to initialize cluster cache - $($_.Exception.Message)" -ForegroundColor Red
        if ($_.Exception.Message -like "*timeout*") {
            Write-Host "    This appears to be a timeout issue. Consider increasing -apiTimeoutSeconds parameter" -ForegroundColor Yellow
        }
        return $null
    }
}
 
# Optimized function to remove missing O365 objects
function Remove-MissingO365Objects {
    param(
        [hashtable]$ClusterCache,
        [string]$ObjectType,
        [switch]$DryRun = $false
    )
   
    # Get object type configuration
    $objectConfig = Get-ObjectTypeConfig -ObjectType $ObjectType
    if (-not $objectConfig) {
        return @{ RemovedCount = 0 }
    }      # Find relevant protection groups
    $relevantJobs = $ClusterCache.ProtectionGroups | Where-Object {
        # First check if the job name matches the expected prefix
        $matchesPrefix = $_.name -match $Task.JobPrefix
       
        if (-not $matchesPrefix) {
            return $false  # Skip jobs that don't match the prefix
        }
       
        # Check protection type - handle both v2 and v1 structures
        if ($_.office365Params) {
            # v2 API structure
            return $_.office365Params.protectionTypes -eq $objectConfig.ObjectKtype
        } elseif ($_.sourceSpecialParameters -and $_.sourceSpecialParameters.o365ProtectionSource) {
            # v1 API structure
            return $_.sourceSpecialParameters.o365ProtectionSource.protectionTypes -eq $objectConfig.ObjectKtype        } else {
            # Unknown structure - check environment for safety
            return ($_.environment -eq 'kO365' -or $_.environment -like 'kO365*')
        }
    }
      if (-not $relevantJobs) {
        Write-Host "    No protection groups found for $ObjectType with prefix '$($Task.JobPrefix)'"
        return @{ RemovedCount = 0 }
    }
   
    Write-Host "    Found $($relevantJobs.Count) protection group(s) for $ObjectType with prefix '$($Task.JobPrefix)'" -ForegroundColor Green
   
    # Get current objects from source
    $currentObjects = Get-O365Objects -ClusterCache $ClusterCache -ObjectConfig $objectConfig
    $currentObjectIds = $currentObjects.Keys
      $totalRemoved = 0
    $skippedJobs = @()
   
    # Update each protection group
    foreach ($job in $relevantJobs) {
        $originalCount = @($job.office365Params.objects).Count       
        $objectsToKeep = @($job.office365Params.objects | Where-Object {$_.id -in $currentObjectIds})
        $newCount = @($objectsToKeep).Count
          if ($newCount -lt $originalCount) {
            $removed = $originalCount - $newCount
            $totalRemoved += $removed
           
            # Identify objects being removed for logging
            $objectsToRemove = @($job.office365Params.objects | Where-Object {$_.id -notin $currentObjectIds})
           
            if ($DryRun) {
                if ($newCount -eq 0) {
                    Write-Host "      [DRY RUN] Would skip updating $($job.name): all objects would be removed (job would be empty)" -ForegroundColor Yellow
                } else {
                    Write-Host "      [DRY RUN] Would update $($job.name): remove $removed deleted objects" -ForegroundColor Yellow
                }
            } else {                if ($newCount -eq 0) {
                    Write-Host "      Skipped updating $($job.name): all objects would be removed (cannot have empty protection job)" -ForegroundColor Yellow
                    Write-Host "        Consider manually reviewing and deleting this job if it's no longer needed" -ForegroundColor Cyan
                    # Don't count these as "removed" since we didn't actually update the job
                    $totalRemoved -= $removed
                    $skippedJobs += $job.name                } else {
                    Write-Host "      Updated $($job.name): removed $removed deleted objects" -ForegroundColor Yellow
                   
                    # Log each removed object
                    foreach ($removedObj in $objectsToRemove) {
                        $objName = if ($currentObjects.ContainsKey($removedObj.id)) {
                            $currentObjects[$removedObj.id]
                        } else {
                            $removedObj.name
                        }
                        if (-not $objName) { $objName = "Unknown" }
                       
                        Write-ObjectLog -Operation "REMOVED" -ObjectId $removedObj.id -ObjectName $objName -JobName $job.name -PolicyName $job.policyId -ClusterName $ClusterCache.Cluster.name
                    }
                   
                    $job.office365Params.objects = $objectsToKeep
                    try {
                        $updateResult = api put -v2 "data-protect/protection-groups/$($job.id)" $job
                        if (-not $updateResult) {
                            Write-Host "        Warning: Failed to update $($job.name) - API returned null" -ForegroundColor Red
                        }
                    }
                    catch {
                        Write-Host "        Error updating $($job.name): $($_.Exception.Message)" -ForegroundColor Red
                        if ($_.Exception.Message -like "*objects in body should have at least 1 items*") {
                            Write-Host "        This error suggests the job would have no valid objects left" -ForegroundColor Red
                        }
                    }
                }
            }
        }    }
   
    return @{
        RemovedCount = $totalRemoved
        SkippedJobs = $skippedJobs
    }
}
 
# Optimized function to add new O365 objects
function Add-NewO365Objects {
    param(
        [hashtable]$ClusterCache,
        [hashtable]$Task,
        [string]$PolicyName,
        [int]$MaxObjectsPerJob,
        [string]$LetterRange = $null,
        [switch]$FillAllGroups = $false,
        [switch]$DryRun = $false
    )
   
    #Write-Host "      [DEBUG] Add-NewO365Objects started for $($Task.ObjectType)" -ForegroundColor DarkGray
   
    # Get object type configuration
    $objectConfig = Get-ObjectTypeConfig -ObjectType $Task.ObjectType
    if (-not $objectConfig) {
        return @{ AddedCount = 0 }
    }
   
    # Get current objects from source
    $allObjects = Get-O365Objects -ClusterCache $ClusterCache -ObjectConfig $objectConfig    # Find existing protection groups for this object type using proven approach
    # Filter by object type first, then by job prefix to ensure we only work with jobs matching our naming convention
    #Write-Host "      Searching for existing jobs with prefix '$($Task.JobPrefix)' and object type '$($objectConfig.ObjectKtype)'" -ForegroundColor Cyan
    #Write-Host "      Total protection groups in cache: $($ClusterCache.ProtectionGroups.Count)" -ForegroundColor Cyan
      # Use the same filtering approach as autoprotectO365.ps1
    $existingJobs = $ClusterCache.ProtectionGroups | Where-Object {$_.office365Params.protectionTypes -eq $objectConfig.ObjectKtype}
    $existingJobs = $existingJobs | Sort-Object -Property name | Where-Object {$_.name -match $Task.JobPrefix}
   
    #Write-Host "      Found $($existingJobs.Count) existing jobs matching criteria" -ForegroundColor Cyan
      # Check if we need to create first job
    if (-not $existingJobs -and -not $createFirstJob) {
        Write-Host "      No existing jobs found for prefix '$($Task.JobPrefix)'" -ForegroundColor Yellow
        Write-Host "      Use -createFirstJob to create the first protection job" -ForegroundColor Yellow
        return @{ AddedCount = 0 }
    }
      # Get currently protected objects using the same approach as autoprotectO365.ps1
    $protectedObjectIds = @($existingJobs.office365Params.objects.id | Where-Object {$_ -ne $null})
      # Find unprotected objects and apply letter range filtering if specified
    $unprotectedObjects = @{}
    $skippedByLetterRange = 0
    $skippedAlreadyProtected = 0
   
    foreach ($objId in $allObjects.Keys) {
        $objName = $allObjects[$objId]
       
        if ($objId -in $protectedObjectIds) {
            $skippedAlreadyProtected++
            continue
        }
       
        # Apply letter range filtering if specified
        if ($letterRange -and -not (Test-ObjectInLetterRange -ObjectName $objName -LetterRange $letterRange)) {
            $skippedByLetterRange++
            # Log skipped object
            Write-SkippedObjectLog -ClusterName $ClusterCache.Cluster.name -ObjectType $Task.ObjectType -ObjectId $objId -ObjectName $objName -LetterRange $letterRange -Reason "Outside letter range filter"
            continue
        }
       
        # Object is unprotected and within letter range (if specified)
        $unprotectedObjects[$objId] = $objName
    }
   
    # Enhanced reporting with letter range information
    if ($letterRange) {
        Write-Host "      $($allObjects.Count) total objects, $($protectedObjectIds.Count) protected, $($unprotectedObjects.Count) unprotected (letter range: $letterRange)" -ForegroundColor Cyan
        Write-Host "      Letter range filtering: $skippedByLetterRange objects skipped (outside range $letterRange)" -ForegroundColor Yellow
    } else {
        Write-Host "      $($allObjects.Count) total objects, $($protectedObjectIds.Count) protected, $($unprotectedObjects.Count) unprotected"
    }
      # Show job capacity analysis for all modes
    if ($existingJobs.Count -gt 0) {
        Write-Host "      Current job capacity analysis:" -ForegroundColor Cyan
        foreach ($job in $existingJobs) {
            $capacity = $MaxObjectsPerJob - $job.office365Params.objects.Count
            $capacityColor = if ($capacity -lt 0) { "Red" } elseif ($capacity -lt 10) { "Yellow" } else { "Green" }
            Write-Host "        - $($job.name): $($job.office365Params.objects.Count)/$MaxObjectsPerJob objects (capacity: $capacity)" -ForegroundColor $capacityColor
        }
          # Log capacity information to file
        Write-CapacityLog -ClusterName $ClusterCache.Cluster.name -ObjectType $Task.ObjectType -Jobs $existingJobs -MaxObjectsPerJob $MaxObjectsPerJob -TotalObjects $allObjects.Count -ProtectedObjects $protectedObjectIds.Count -UnprotectedObjects $unprotectedObjects.Count
    }
      # Log letter range filtering summary if applicable
    if ($LetterRange) {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $filterSummary = "$timestamp | LETTER_RANGE_FILTER | Cluster: $($ClusterCache.Cluster.name) | ObjectType: $($Task.ObjectType) | Range: $LetterRange | TotalObjects: $($allObjects.Count) | SkippedByRange: $skippedByLetterRange | EligibleForProcessing: $($unprotectedObjects.Count)"
        Write-SafeLog -Message $filterSummary
    }
   
    # Log processing strategy
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $strategy = if ($FillAllGroups) { "FILL_ALL_GROUPS" } else { "FILL_RECENT_GROUP_ONLY" }
    $strategySummary = "$timestamp | PROCESSING_STRATEGY | Cluster: $($ClusterCache.Cluster.name) | ObjectType: $($Task.ObjectType) | Strategy: $strategy | ExistingJobs: $($existingJobs.Count)"
    Write-SafeLog -Message $strategySummary
   
    if ($unprotectedObjects.Count -eq 0) {
        return @{ AddedCount = 0 }
    }
   
    # In test mode, show sample of unprotected objects
    if ($testMode) {
        Write-Host "      Sample unprotected objects:" -ForegroundColor Cyan
        $sampleObjects = $unprotectedObjects.GetEnumerator() | Select-Object -First 10
        foreach ($obj in $sampleObjects) {
            Write-Host "        - $($obj.Value) (ID: $($obj.Key))"
        }
        if ($unprotectedObjects.Count -gt 10) {
            Write-Host "        ... and $($unprotectedObjects.Count - 10) more"
        }
    }    if ($DryRun) {
        # In dry run mode, just report what would be done
        Write-Host "      [DRY RUN] Would process $($unprotectedObjects.Count) unprotected objects" -ForegroundColor Yellow
        if ($FillAllGroups) {
            Write-Host "      [DRY RUN] Strategy: Fill all existing groups before creating new ones" -ForegroundColor Cyan
        } else {
            Write-Host "      [DRY RUN] Strategy: Fill only the most recent group before creating new ones" -ForegroundColor Cyan
        }
       
        return @{ AddedCount = $unprotectedObjects.Count }
    }
   
    # Show processing strategy
    if ($FillAllGroups) {
        Write-Host "      Using strategy: Fill all existing groups before creating new ones" -ForegroundColor Cyan
    } else {
        Write-Host "      Using strategy: Fill only the most recent group before creating new ones" -ForegroundColor Cyan
    }
   
    $totalAdded = 0
    $unprotectedObjectIds = @($unprotectedObjects.Keys)    # Process unprotected objects
    while ($unprotectedObjectIds.Count -gt 0) {
        # Find a job with capacity or create new one
        $targetJob = $null
       
        if ($FillAllGroups) {
            # Fill all existing groups strategy: Find any job with capacity (fills older jobs first)
            #Write-Host "      [DEBUG] Using FILL_ALL_GROUPS strategy" -ForegroundColor DarkGray
            foreach ($job in $existingJobs) {
                if ($job.office365Params.objects.Count -lt $MaxObjectsPerJob) {
                    $targetJob = $job
                    #Write-Host "      [DEBUG] Selected job for filling: $($job.name) ($($job.office365Params.objects.Count)/$MaxObjectsPerJob objects)" -ForegroundColor DarkGray
                    break
                }
            }        } else {
            # Default strategy: Fill only the most recent job before creating new ones
            #Write-Host "      [DEBUG] Using FILL_RECENT_GROUP_ONLY strategy" -ForegroundColor DarkGray
            #Write-Host "      [DEBUG] Current jobs in order: $($existingJobs | ForEach-Object { $_.name }) " -ForegroundColor DarkGray
           
            # Find the job with the highest numerical suffix (most recent)
            $mostRecentJob = $null
            $highestNumber = -1
           
            foreach ($job in $existingJobs) {
                if ($job.name -match '-(\d{3})$') {
                    $jobNumber = [int]$matches[1]
                    if ($jobNumber -gt $highestNumber) {
                        $highestNumber = $jobNumber
                        $mostRecentJob = $job
                    }
                }
            }
           
            if ($mostRecentJob) {
                #Write-Host "      [DEBUG] Most recent job (by number): $($mostRecentJob.name) ($($mostRecentJob.office365Params.objects.Count)/$MaxObjectsPerJob objects)" -ForegroundColor DarkGray
            }
            if ($mostRecentJob -and $mostRecentJob.office365Params.objects.Count -lt $MaxObjectsPerJob) {
                $targetJob = $mostRecentJob
                #Write-Host "      [DEBUG] Selected most recent job for filling: $($targetJob.name)" -ForegroundColor DarkGray
            } else {
                #Write-Host "      [DEBUG] Most recent job is full or doesn't exist, will create new job" -ForegroundColor DarkGray
            }
        }if (-not $targetJob) {
            # Ensure we have at least one object to create a job with
            if ($unprotectedObjectIds.Count -eq 0) {
                Write-Host "      No more objects to process"
                break
            }
           
            #Write-Host "      [DEBUG] No suitable existing job found, creating new job" -ForegroundColor DarkGray            # Create new job with the first object
            $firstObjectId = $unprotectedObjectIds[0]
            $firstObjectName = $unprotectedObjects[$firstObjectId]
           
            $targetJob = New-O365ProtectionJob -ClusterCache $ClusterCache -Task $Task -PolicyName $PolicyName -MaxObjectsPerJob $MaxObjectsPerJob -FirstJobNum $firstJobNum -DisableIndexing $disableIndexing -FullSlaMinutes $fullSlaMinutes -IncrementalSlaMinutes $incrementalSlaMinutes -StartTime $startTime -TimeZone $timeZone -FirstObjectId $firstObjectId -FirstObjectName $firstObjectName
            if ($targetJob) {
                #Write-Host "      [DEBUG] Successfully created new job: $($targetJob.name)" -ForegroundColor DarkGray
                # Log the first object added during job creation
                Write-ObjectLog -Operation "ADDED" -ObjectId $firstObjectId -ObjectName $firstObjectName -JobName $targetJob.name -PolicyName $PolicyName -ClusterName $ClusterCache.Cluster.name
               
                # Refresh the job from API to get accurate object count
                try {
                    $refreshedJob = api get -v2 "data-protect/protection-groups/$($targetJob.id)"
                    if ($refreshedJob) {
                        $targetJob = $refreshedJob
                        #Write-Host "      [DEBUG] Refreshed job data from API: $($targetJob.name) has $($targetJob.office365Params.objects.Count) objects" -ForegroundColor DarkGray
                    }
                } catch {
                    #Write-Host "      [DEBUG] Warning: Could not refresh job data from API: $($_.Exception.Message)" -ForegroundColor Yellow
                }
               
                # Add to existing jobs list and re-sort
                $existingJobsList = @($existingJobs)
                $existingJobsList += $targetJob
                $existingJobs = $existingJobsList | Sort-Object -Property name
 
                #Write-Host "      [DEBUG] Updated job list count: $($existingJobs.Count)" -ForegroundColor DarkGray
 
                # Remove the first object from the list since it's already in the job
                $unprotectedObjectIds = $unprotectedObjectIds | Where-Object {$_ -ne $firstObjectId}
                $totalAdded++
                Write-Host "      Created new protection job: $($targetJob.name)"
                continue
            } else {
                Write-Host "      Failed to create new protection job - stopping" -ForegroundColor Red
                break
            }
        }
          # Add objects to job
        $availableSlots = $MaxObjectsPerJob - $targetJob.office365Params.objects.Count
        $objectsToAdd = $unprotectedObjectIds | Select-Object -First $availableSlots
          foreach ($objId in $objectsToAdd) {
            # Ensure we have a proper array and add the object
            if ($null -eq $targetJob.office365Params.objects) {
                $targetJob.office365Params.objects = @()
            }
            # Convert to ArrayList to avoid op_Addition errors
            $objectsList = [System.Collections.ArrayList]@($targetJob.office365Params.objects)
            $null = $objectsList.Add(@{'id' = $objId})
            $targetJob.office365Params.objects = $objectsList.ToArray()
            $totalAdded++
        }        # Update job
        try {
            $updateResult = api put -v2 "data-protect/protection-groups/$($targetJob.id)" $targetJob
            if ($updateResult) {
                # Refresh the job data to get accurate object count for next iteration
                try {
                    $refreshedJob = api get -v2 "data-protect/protection-groups/$($targetJob.id)"
                    if ($refreshedJob) {
                        # Update the job in our existing jobs array
                        for ($i = 0; $i -lt $existingJobs.Count; $i++) {
                            if ($existingJobs[$i].id -eq $targetJob.id) {
                                $existingJobs[$i] = $refreshedJob
                                $targetJob = $refreshedJob
                                #Write-Host "      [DEBUG] Refreshed job data: $($targetJob.name) now has $($targetJob.office365Params.objects.Count) objects" -ForegroundColor DarkGray
                                break
                            }
                        }
                    }
                } catch {
                    #Write-Host "      [DEBUG] Warning: Could not refresh job data after update: $($_.Exception.Message)" -ForegroundColor Yellow
                }
               
                # Log each added object
                foreach ($objId in $objectsToAdd) {
                    $objName = if ($unprotectedObjects.ContainsKey($objId)) {
                        $unprotectedObjects[$objId]
                    } else {
                        "Unknown"
                    }
                    Write-ObjectLog -Operation "ADDED" -ObjectId $objId -ObjectName $objName -JobName $targetJob.name -PolicyName $PolicyName -ClusterName $ClusterCache.Cluster.name
                }
               
                Write-Host "      Added $($objectsToAdd.Count) objects to $($targetJob.name) (total Objects in Group: $($targetJob.office365Params.objects.Count))"
            } else {
                Write-Host "      Warning: Update API call returned null for $($targetJob.name)" -ForegroundColor Yellow
            }
        }
        catch {
            Write-Host "      Error updating job $($targetJob.name): $($_.Exception.Message)" -ForegroundColor Red
            # Don't break the loop, continue with remaining objects
        }
          # Remove processed objects
        $unprotectedObjectIds = $unprotectedObjectIds | Where-Object {$_ -notin $objectsToAdd}
    }
 
    #Write-Host "      [DEBUG] Add-NewO365Objects completed for $($Task.ObjectType), returning $totalAdded" -ForegroundColor DarkGray
    return @{ AddedCount = $totalAdded }
}
 
# Get O365 objects efficiently with minimal API calls
function Get-O365Objects {
    param(
        [hashtable]$ClusterCache,
        [hashtable]$ObjectConfig
    )
   
    # Find the appropriate node
    $objectsNode = $ClusterCache.Source.nodes | Where-Object {
        $_.protectionSource.name -eq $ObjectConfig.NodeString
    }
   
    if (-not $objectsNode) {
        Write-Warning "Node $($ObjectConfig.NodeString) not found"
        return @{}
    }
   
    $objects = @{}
    $lastCursor = 0
   
    # Initial API call
    $queryParam = if ($ObjectConfig.QueryParam) { $ObjectConfig.QueryParam } else { "" }
    $apiResult = api get "protectionSources?pageSize=50000&nodeId=$($objectsNode.protectionSource.id)&id=$($objectsNode.protectionSource.id)&allUnderHierarchy=false$($queryParam)&useCachedData=false"
    $cursor = $apiResult.entityPaginationParameters.beforeCursorEntityId
   
    # Process all pages
    while ($true) {
        foreach ($node in $apiResult.nodes) {
            $objects[$node.protectionSource.id] = $node.protectionSource.name
            $lastCursor = $node.protectionSource.id
        }
       
        if ($cursor) {
            $apiResult = api get "protectionSources?pageSize=50000&nodeId=$($objectsNode.protectionSource.id)&id=$($objectsNode.protectionSource.id)&allUnderHierarchy=false$($queryParam)&useCachedData=false&afterCursorEntityId=$cursor"
            $cursor = $apiResult.entityPaginationParameters.beforeCursorEntityId
        } else {
            break
        }
       
        # Handle 6.8.1 patch
        if (-not $apiResult.nodes -and $cursor -gt $lastCursor) {
            $node = api get "protectionSources?id=$cursor$($queryParam)"
            $objects[$node.protectionSource.id] = $node.protectionSource.name
            $lastCursor = $node.protectionSource.id
        }
       
        if ($cursor -eq $lastCursor) {
            break
        }
    }
   
    return $objects
}
 
# Create new O365 protection job
function New-O365ProtectionJob {
    param(
        [hashtable]$ClusterCache,
        [hashtable]$Task,
        [string]$PolicyName,
        [int]$MaxObjectsPerJob,
        [string]$FirstJobNum = '001',
        [bool]$DisableIndexing = $false,
        [int]$FullSlaMinutes = 1440,
        [int]$IncrementalSlaMinutes = 720,        [string]$StartTime = '16:00',
        [string]$TimeZone = 'America/Los_Angeles',
        [string]$FirstObjectId = $null,
        [string]$FirstObjectName = $null
    )    try {
        # Get policy
        $policy = (api get -v2 "data-protect/policies").policies | Where-Object name -eq $PolicyName
        if (-not $policy) {            Write-Host "      ERROR: Policy $PolicyName not found" -ForegroundColor Red
            return $null
        }
       
        # Get storage domain
        try {
            $viewBoxes = api get viewBoxes
            $viewBox = if ($viewBoxes -is [array]) {
                $viewBoxes | Where-Object { $_.name -ieq "DefaultStorageDomain" }
            } else {
                $viewBoxes[0]
            }
            if (-not $viewBox) {                Write-Host "      ERROR: Storage domain DefaultStorageDomain not found" -ForegroundColor Red
                return $null
            }
        }
        catch {            Write-Host "      ERROR: Failed to get storage domains: $($_.Exception.Message)" -ForegroundColor Red
            return $null
        }
       
        # Generate job name
        try {            # Get current existing jobs (refresh the list to include any newly created jobs)
            $currentExistingJobs = (api get -v2 "data-protect/protection-groups?environments=kO365").protectionGroups | Where-Object {
                $_.isDeleted -ne $True -and $_.isActive -eq $True -and
                (($_.office365Params -and $_.office365Params.protectionTypes -eq (Get-ObjectTypeConfig -ObjectType $Task.ObjectType).ObjectKtype) -or
                 ($_.sourceSpecialParameters -and $_.sourceSpecialParameters.o365ProtectionSource -and $_.sourceSpecialParameters.o365ProtectionSource.protectionTypes -eq (Get-ObjectTypeConfig -ObjectType $Task.ObjectType).ObjectKtype)) -and
                $_.name -match $Task.JobPrefix
            } | Sort-Object -Property name
           
            $jobNumber = if ($currentExistingJobs) {
                $lastJob = $currentExistingJobs[-1]
                $currentNum = $lastJob.name -replace '.*(?:\D|^)(\d+)','$1'
                "{0:d$($currentNum.Length)}" -f ([int]$currentNum + 1)
            } else {
                $FirstJobNum
            }            $jobName = "$($Task.JobPrefix)$jobNumber"
        }
        catch {
            Write-Host "      ERROR: Failed to generate job name: $($_.Exception.Message)" -ForegroundColor Red
            return $null
        }
       
        # Get object configuration
        try {
            $objectConfig = Get-ObjectTypeConfig -ObjectType $Task.ObjectType
            if (-not $objectConfig) {
                Write-Host "      ERROR: Failed to get object configuration for $($Task.ObjectType)" -ForegroundColor Red
                return $null
            }
            $environment = if ($ClusterCache.Cluster.clusterSoftwareVersion -gt '6.8') {
                $objectConfig.Environment68            } else {
                'kO365'
            }
        }
        catch {
            Write-Host "      ERROR: Failed to get object configuration: $($_.Exception.Message)" -ForegroundColor Red
            return $null
        }        # Parse start time
        try {
            $hour, $minute = $StartTime.split(':')
            if (-not $hour -or -not $minute) {                Write-Host "      ERROR: Invalid start time format: $StartTime" -ForegroundColor Red
                return $null
            }
        }
        catch {
            Write-Host "      ERROR: Failed to parse start time '$StartTime': $($_.Exception.Message)" -ForegroundColor Red
            return $null
        }        # Create objects array separately to avoid hashtable issues        try {
            if ($FirstObjectId -and $FirstObjectName) {
                $singleObject = @{
                    'id' = [int64]$FirstObjectId
                    'name' = $FirstObjectName
                }
               
                # Force creation of a proper array containing this object
                $jobObjects = @($singleObject)
            } else {
                Write-Warning "Creating job without initial object - this may cause API errors"
                $jobObjects = @()
            }
        }
        catch {
            Write-Host "      ERROR: Failed to create objects array: $($_.Exception.Message)" -ForegroundColor Red
            return $null
        }
       
        # Create job definition
       
        # Create job definition
        $newJob = @{
            "policyId" = $policy.id
            "isPaused" = $false
            "startTime" = @{
                "hour" = [int]$hour
                "minute" = [int]$minute
                "timeZone" = $TimeZone
            }
            "priority" = "kMedium"
            "sla" = @(                @{
                    "backupRunType" = "kFull"
                    "slaMinutes" = $fullSlaMinutes
                },
                @{
                    "backupRunType" = "kIncremental"
                    "slaMinutes" = $incrementalSlaMinutes
                }
            )
            "qosPolicy" = "kBackupHDD"
            "abortInBlackouts" = $false
            "storageDomainId" = $viewBox.id
            "name" = $jobName
            "environment" = $environment
            "description" = ""
            "alertPolicy" = @{
                "backupRunStatus" = @("kFailure")
                "alertTargets" = @()
            }
            "office365Params" = @{               
                "indexingPolicy" = @{
                    "enableIndexing" = -not $DisableIndexing
                    "includePaths" = @("/")
                    "excludePaths" = @()
                }                   
                "objects" = @($jobObjects)  # Ensure this is always an array
                "excludeObjectIds" = @()               
                "protectionTypes" = @($objectConfig.ObjectKtype)
                "outlookProtectionTypeParams" = $null
                "oneDriveProtectionTypeParams" = $null               
                "publicFoldersProtectionTypeParams" = $null
            }        }
       
        # Ensure we have at least one object before creating the job
        if (-not $FirstObjectId -or -not $FirstObjectName) {
            Write-Host "      Cannot create job without at least one object (ID and Name required)" -ForegroundColor Red
            return $null
        }
       
        # Create the job with the first object
        $result = api post -v2 "data-protect/protection-groups" $newJob
       
        if (-not $result -or -not $result.id) {
            return $null
        }
 
        # Return the created job with ID
        $newJob.id = $result.id
        return $newJob
    }
 
 
# Get object type configuration
function Get-ObjectTypeConfig {
    param([string]$ObjectType)
   
    switch ($ObjectType) {
        'mailbox' {
            return @{
                ObjectString = 'Mailboxes'
                NodeString = 'users'
                ObjectKtype = 'kMailbox'
                Environment68 = 'kO365Exchange'
                QueryParam = '&hasValidMailbox=true&hasValidOnedrive=false'
            }
        }
        'onedrive' {
            return @{
                ObjectString = 'OneDrives'
                NodeString = 'users'
                ObjectKtype = 'kOneDrive'
                Environment68 = 'kO365OneDrive'
                QueryParam = '&hasValidOnedrive=true&hasValidMailbox=false'
            }
        }
        'sites' {
            return @{
                ObjectString = 'Sites'
                NodeString = 'Sites'
                ObjectKtype = 'kSharePoint'
                Environment68 = 'kO365Sharepoint'
                QueryParam = ''
            }
        }
        'teams' {
            return @{
                ObjectString = 'Teams'
                NodeString = 'Teams'
                ObjectKtype = 'kTeams'
                Environment68 = 'kO365Teams'
                QueryParam = ''
            }
        }
        'publicfolders' {
            return @{
                ObjectString = 'PublicFolders'
                NodeString = 'PublicFolders'
                ObjectKtype = 'kPublicFolders'
                Environment68 = 'kO365PublicFolders'
                QueryParam = ''
            }
        }
        default {
            Write-Error "Invalid object type: $ObjectType"
            return $null
        }
    }
}
 
# Show cluster discovery information (useful for test mode)
function Show-ClusterDiscovery {
    param(
        [hashtable]$ClusterCache
    )
   
    Write-Host "`n  Cluster Discovery Information:" -ForegroundColor Green
    Write-Host "  =============================="
   
    # Show basic cluster info
    Write-Host "  Cluster Name: $($ClusterCache.Cluster.name)"
    Write-Host "  Cluster Version: $($ClusterCache.Cluster.clusterSoftwareVersion)"
    Write-Host "  Root Source: $($ClusterCache.RootSource.protectionSource.name)"
   
    # Show available nodes
    Write-Host "`n  Available O365 Nodes:"
    foreach ($node in $ClusterCache.Source.nodes) {
        Write-Host "    - $($node.protectionSource.name) (ID: $($node.protectionSource.id))"
    }
      # Show existing protection groups by type
    Write-Host "`n  Existing Protection Groups:"
    $groupsByType = $ClusterCache.ProtectionGroups | Group-Object {
        if ($_.office365Params) {
            $_.office365Params.protectionTypes
        } elseif ($_.sourceSpecialParameters -and $_.sourceSpecialParameters.o365ProtectionSource) {
            $_.sourceSpecialParameters.o365ProtectionSource.protectionTypes
        } else {
            "Unknown"
        }
    }
    foreach ($group in $groupsByType) {
        Write-Host "    $($group.Name): $($group.Count) groups"
        foreach ($job in $group.Group | Sort-Object name) {
            $objectCount = if ($job.office365Params.objects) { $job.office365Params.objects.Count } else { 0 }
            Write-Host "      - $($job.name) ($objectCount objects)"
        }
    }
   
    # Show policies available
    try {
        $policies = (api get -v2 "data-protect/policies").policies
        Write-Host "`n  Available Policies:"
        foreach ($policy in $policies | Sort-Object name) {
            Write-Host "    - $($policy.name)"
        }
    }
    catch {
        Write-Warning "    Could not retrieve policies: $($_.Exception.Message)"
    }
   
    # Show storage domains
    try {
        $viewBoxes = api get viewBoxes
        Write-Host "`n  Available Storage Domains:"
        if ($viewBoxes -is [array]) {
            foreach ($vb in $viewBoxes | Sort-Object name) {
                Write-Host "    - $($vb.name)"
            }
        } else {
            Write-Host "    - $($viewBoxes.name)"
        }
    }
    catch {
        Write-Warning "    Could not retrieve storage domains: $($_.Exception.Message)"
    }
}
 
# Safety check function to prevent accidental mass additions
function Test-SafetyLimits {
    param(
        [hashtable]$ClusterCache,
        [array]$Tasks,
        [int]$MaxObjectsPerRun,
        [int]$MaxObjectsPerType,
        [switch]$IgnoreSafetyLimit = $false
    )
   
    if ($IgnoreSafetyLimit) {
        Write-Host "  SAFETY LIMITS BYPASSED - Proceeding without limits" -ForegroundColor Red
        return $true
    }
   
    $totalUnprotectedObjects = 0
    $objectTypeBreakdown = @{
    }
   
    Write-Host "`n  Performing safety check..." -ForegroundColor Cyan
    Write-Host "`n"
   
    foreach ($task in $Tasks) {
        # Get object type configuration
        $objectConfig = Get-ObjectTypeConfig -ObjectType $task.ObjectType
        if (-not $objectConfig) {
            continue
        }
       
        # Get current objects from source
        $allObjects = Get-O365Objects -ClusterCache $ClusterCache -ObjectConfig $objectConfig
          # Find existing protection groups for this object type
        $existingJobs = $ClusterCache.ProtectionGroups | Where-Object {
            # Check if job name matches prefix
            if ($_.name -notmatch $task.JobPrefix) {
                return $false
            }
           
            # Check protection type - handle both v2 and v1 structures
            if ($_.office365Params) {
                # v2 API structure
                return $_.office365Params.protectionTypes -eq $objectConfig.ObjectKtype
            } elseif ($_.sourceSpecialParameters -and $_.sourceSpecialParameters.o365ProtectionSource) {
                # v1 API structure
                return $_.sourceSpecialParameters.o365ProtectionSource.protectionTypes -eq $objectConfig.ObjectKtype            } else {
                # Unknown structure - check environment and name for safety
                return ($_.environment -eq 'kO365' -or $_.environment -like 'kO365*')
            }
        }
       
        # Get currently protected objects
        $protectedObjectIds = @()
        foreach ($job in $existingJobs) {
            # Handle both v2 and v1 API structures for objects
            if ($job.office365Params -and $job.office365Params.objects) {
                # v2 API structure
                $protectedObjectIds = $protectedObjectIds + $job.office365Params.objects.id
            } elseif ($job.sourceSpecialParameters -and $job.sourceSpecialParameters.o365ProtectionSource -and $job.sourceSpecialParameters.o365ProtectionSource.objects) {
                # v1 API structure
                $protectedObjectIds = $protectedObjectIds + $job.sourceSpecialParameters.o365ProtectionSource.objects.id
            }
        }
       
        # Count unprotected objects
        $unprotectedCount = 0
        foreach ($objId in $allObjects.Keys) {
            if ($objId -notin $protectedObjectIds) {
                $unprotectedCount++
            }
        }
       
        $objectTypeBreakdown[$task.ObjectType] = @{
            Total = $allObjects.Count
            Protected = $protectedObjectIds.Count
            Unprotected = $unprotectedCount
            Description = $task.Description
        }
       
        $totalUnprotectedObjects += $unprotectedCount
    }
   
    # Display safety check results
    Write-Host "  Safety Check Results:" -ForegroundColor Green
    Write-Host "  ===================="
    Write-Host "Set Max Jobs Per Object Type: $($maxObjectsToAddPerObjectType)"
    Write-Host "Set Max Objects Per Run: $($maxObjectsToAddPerRun)"
    Write-Host ""
    foreach ($objectType in $objectTypeBreakdown.Keys) {
        $breakdown = $objectTypeBreakdown[$objectType]
        Write-Host "    $($breakdown.Description): $($breakdown.Unprotected) unprotected objects (of $($breakdown.Total) total)"
    }
    Write-Host "    TOTAL UNPROTECTED: $totalUnprotectedObjects objects"
    Write-Host ""
   
    # Check per-object-type limits
    $perTypeViolations = @()
    foreach ($objectType in $objectTypeBreakdown.Keys) {
        $breakdown = $objectTypeBreakdown[$objectType]
        if ($breakdown.Unprotected -gt $MaxObjectsPerType) {
            $perTypeViolations += "    - $($breakdown.Description): $($breakdown.Unprotected) objects (limit: $MaxObjectsPerType)"
        }
    }
   
    # Check total limit
    $totalLimitExceeded = $totalUnprotectedObjects -gt $MaxObjectsPerRun
   
    if ($perTypeViolations.Count -gt 0 -or $totalLimitExceeded) {
        Write-Host "  SAFETY LIMIT EXCEEDED!" -ForegroundColor Red
        Write-Host "  ====================" -ForegroundColor Red
       
        if ($totalLimitExceeded) {
            Write-Host "    Total objects to add ($totalUnprotectedObjects) exceeds safety limit ($MaxObjectsPerRun)" -ForegroundColor Red
        }
       
        if ($perTypeViolations.Count -gt 0) {
            Write-Host "    Per-object-type limit violations:" -ForegroundColor Red
            foreach ($violation in $perTypeViolations) {
                Write-Host $violation -ForegroundColor Red
            }
        }
       
        Write-Host ""
        Write-Host "  To proceed anyway, use the -ignoreSafetyLimit parameter" -ForegroundColor Yellow
        Write-Host "  This safety check prevents accidental mass additions that could" -ForegroundColor Yellow
        Write-Host "  overwhelm the system or indicate a configuration problem." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  Safety limits can be adjusted in the script configuration:" -ForegroundColor Yellow
        Write-Host "    - `$maxObjectsToAddPerRun = $MaxObjectsPerRun" -ForegroundColor Yellow
        Write-Host "    - `$maxObjectsToAddPerObjectType = $MaxObjectsPerType" -ForegroundColor Yellow
       
        return $false
    }
   
    Write-Host "  Safety check PASSED - Within acceptable limits" -ForegroundColor Green
    Write-Host "`n================================================"
    return $true
}
 
# Main execution
try {
    foreach ($cluster in $clusters) {
        Process-Cluster -ClusterConfig $cluster -Username $arg_username -Password $arg_password -Domain $domain -DryRun:$dryRun
    }
      Write-Host "`n================================================"
    if ($testMode) {
        if ($dryRun) {
            Write-Host "Test Cluster Dry Run Completed - No changes were made" -ForegroundColor Yellow
        } else {
            Write-Host "Test Cluster Execution Completed - Changes were applied" -ForegroundColor Green
        }
    } else {
        if ($dryRun) {
            Write-Host "Production Dry Run Completed - No changes were made" -ForegroundColor Yellow
        } else {
            Write-Host "Production Execution Completed Successfully - Changes were applied" -ForegroundColor Green
        }
    }
}
catch {
    Write-Host "`n================================================" -ForegroundColor Red
    Write-Host "SCRIPT EXECUTION FAILED" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "================================================" -ForegroundColor Red
    exit 1
}