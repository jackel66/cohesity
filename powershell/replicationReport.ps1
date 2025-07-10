# Cohesity Replication Summary Script
# This script retrieves and summarizes pending replication tasks across Cohesity protection jobs.  
# It provides detailed information about each job, including the number of pending tasks, oldest task time, remote cluster, and total data being transferred.
# It can filter jobs by name, age of tasks, and remote cluster.
# Usage:
#   replication-summary.ps1 -vip <cluster_vip> -username <username> -
#   -password <password> [-domain <domain>] [-clustername <cluster_name>] [-mcm] [-useApiKey] [-noprompt]
#   [-mfacode <mfa_code>] [-jobname <job_name>] [-joblist <job_list_file>] [-remotecluster <remote_cluster>]

# Version 1.3


# Command line parameters
param(
    [string]$vip = 'helios.cohesity.com', # Default Cohesity cluster VIP
    [string]$username,
    [string]$domain,
    [string]$clustername = $null,
    [switch]$mcm,
    [switch]$useApiKey,
    [string]$password = $null,
    [switch]$noprompt,
    [string]$mfacode = $null,
    [string[]]$jobname = @(),
    [string]$joblist = $null,
    [string]$remotecluster = $null,
    [int]$olderthan = 0,
    [int]$youngerthan = 0,
    [int]$numruns = 9999,
    [ValidateSet('MiB', 'GiB')]
    [string]$units = 'GiB', # Default units for data transfer calculation
    [switch]$summary # Switch to show summary by job instead of individual tasks
)
 
. "$PSScriptRoot\cohesity-api.ps1"
 
# Authenticate to Cohesity cluster
try {
    $authParams = @{
        vip = $vip
        username = $username
        domain = $domain
    }
   
    # Add optional parameters if provided
    if ($password) { $authParams.password = $password }
    if ($useApiKey) { $authParams.useApiKey = $true }
    if ($mcm -or $vip.ToLower() -eq 'helios.cohesity.com') { $authParams.helios = $true }
    if ($noprompt) { $authParams.noprompt = $true }
    if ($mfacode) { $authParams.mfaCode = $mfacode }
   
    apiauth @authParams
   
    # If connected to Helios or MCM, select access cluster
    if ($mcm -or $vip.ToLower() -eq 'helios.cohesity.com') {
        if ($clustername) {
            heliosCluster $clustername
        }
        else {
            Write-Host "-clustername is required when connecting to Helios or MCM" -ForegroundColor Red
            exit 1
        }
    }
}
catch {
    Write-Host "Authentication failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
 
# Calculate time thresholds
$olderthanusecs = $null
$youngerthanusecs = $null
if ($olderthan -gt 0) {
    $olderthanusecs = [DateTimeOffset]::Now.AddDays(-$olderthan).ToUnixTimeMilliseconds() * 1000
}
if ($youngerthan -gt 0) {
    $youngerthanusecs = [DateTimeOffset]::Now.AddDays(-$youngerthan).ToUnixTimeMilliseconds() * 1000
}
 
# Function to gather job list from parameters and/or file
function Get-JobList {
    param(
        [string[]]$JobNames,
        [string]$JobListFile
    )
   
    $jobs = @()
   
    if ($JobNames) {
        $jobs += $JobNames
    }
   
    if ($JobListFile -and (Test-Path $JobListFile)) {
        $fileJobs = Get-Content $JobListFile | Where-Object { $_.Trim() -ne '' }
        $jobs += $fileJobs
    }
   
    return $jobs
}
 
# Get job names list
$jobnames = Get-JobList -JobNames $jobname -JobListFile $joblist
 
# Define finished states
$finishedStates = @('kCanceled', 'kSuccess', 'kFailure', 'kWarning')
 
# Set multiplier for units
$multiplier = 1024 * 1024
if ($units.ToLower() -eq 'gib') {
    $multiplier = 1024 * 1024 * 1024
}
 
# Get current time in microseconds
$now = Get-Date
$nowUsecs = [DateTimeOffset]::Now.ToUnixTimeMilliseconds() * 1000
 
# Function to convert microseconds to date string
function Convert-UsecsToDate {
    param([long]$usecs)
    $epoch = Get-Date "1970-01-01 00:00:00"
    return $epoch.AddMilliseconds($usecs / 1000).ToString("yyyy-MM-dd HH:mm:ss")
}
 
# Initialize tracking for individual tasks and summary
$replicationTasks = @()
$jobSummary = @{}
$jobTransferred = @{}
$jobOldestTask = @{}
$jobRemoteCluster = @{}
 
Write-Host "Scanning for pending replication tasks..." -ForegroundColor Yellow
 
# Get all protection jobs
$jobs = api get protectionJobs
 
# Process each job
foreach ($job in ($jobs | Sort-Object { $_.name.ToLower() })) {
    if (-not $job.PSObject.Properties['isDeleted']) {
        $jobId = $job.id
        [string]$jobName = $job.name
       
        # Check if we should process this job
        $shouldProcess = $false
        if ($jobnames.Count -eq 0) {
            $shouldProcess = $true
        } else {
            foreach ($filterJobName in $jobnames) {
                if ($jobName.ToLower() -eq $filterJobName.ToLower()) {
                    $shouldProcess = $true
                    break
                }
            }
        }
       
        if ($shouldProcess) {
            Write-Host "." -NoNewline
           
            # Get protection runs for this job
            $runs = api get "protectionRuns?jobId=$jobId&numRuns=$numruns&excludeTasks=true&excludeNonRestoreableRuns=true&endTimeUsecs=$nowUsecs"
           
            # Filter runs by age if specified
            if ($olderthan -gt 0) {
                $runs = $runs | Where-Object { $_.backupRun.stats.startTimeUsecs -lt $olderthanusecs }
            }
            if ($youngerthan -gt 0) {
                $runs = $runs | Where-Object { $_.backupRun.stats.startTimeUsecs -gt $youngerthanusecs }
            }
           
            foreach ($run in $runs) {
                $runStartTimeUsecs = $run.backupRun.stats.startTimeUsecs
               
                if ($run.PSObject.Properties['copyRun']) {
                    foreach ($copyRun in $run.copyRun) {
                        # Check if this is a remote replication task
                        if ($copyRun.target.type -eq 'kRemote') {
                            if ($copyRun.status -notin $finishedStates) {
                                if (-not $remotecluster -or $copyRun.target.replicationTarget.clusterName.ToLower() -eq $remotecluster.ToLower()) {
                                    # Create task object for individual tracking
                                    $taskStartTime = Convert-UsecsToDate $runStartTimeUsecs
                                    $transferred = 0
                                    if ($copyRun.PSObject.Properties['stats'] -and $copyRun.stats -and $copyRun.stats.PSObject.Properties['physicalBytesTransferred']) {
                                        $transferred = [Math]::Round([double]$copyRun.stats.physicalBytesTransferred / $multiplier, 2)
                                    }
                                   
                                    # Always create individual task objects
                                    $taskObject = [PSCustomObject]@{
                                        JobName = $jobName
                                        TaskStartTime = $taskStartTime
                                        TaskStartTimeUsecs = $runStartTimeUsecs
                                        Status = $copyRun.status
                                        RemoteCluster = $copyRun.target.replicationTarget.clusterName
                                        TransferredData = $transferred
                                        RunId = $run.backupRun.jobRunId
                                    }
                                    $replicationTasks += $taskObject
                                   
                                    # Also track summary data if summary mode is requested
                                    if ($summary) {
                                        if (-not $jobSummary.ContainsKey($jobName)) {
                                            $jobSummary[$jobName] = 0
                                            $jobTransferred[$jobName] = [double]0.0
                                            $jobOldestTask[$jobName] = [long]$runStartTimeUsecs
                                            $jobRemoteCluster[$jobName] = $copyRun.target.replicationTarget.clusterName
                                        }
                                        $jobSummary[$jobName] = $jobSummary[$jobName] + 1
                                       
                                        # Update oldest task time
                                        $oldestTaskValue = $jobOldestTask[$jobName]
                                        [long]$currentOldest = if ($oldestTaskValue -is [array]) { $oldestTaskValue[0] } else { $oldestTaskValue }
                                        [long]$currentRunTime = $runStartTimeUsecs
                                        if ($currentRunTime -lt $currentOldest) {
                                            $jobOldestTask[$jobName] = $currentRunTime
                                        }
                                       
                                        # Update transferred data
                                        $transferredValue = $jobTransferred[$jobName]
                                        [double]$currentTransferred = if ($transferredValue -is [array]) { $transferredValue[0] } else { $transferredValue }
                                        $jobTransferred[$jobName] = $currentTransferred + $transferred
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
 
Write-Host "`n" # New line after progress dots
 
# Display results based on mode
if ($replicationTasks.Count -gt 0) {
    if ($summary) {
        # Display summary by job
        Write-Host "`n=== SUMMARY OF PENDING REPLICATION TASKS BY JOB ===" -ForegroundColor Green
        Write-Host "Job Name                                    Pending  Oldest Task          Remote Cluster           Total $($units.ToUpper())"
        Write-Host "--------                                    -------  -----------          --------------           -----------"
       
        [int]$totalPendingTasks = 0
        [double]$totalTransferred = 0
       
        foreach ($jobName in ($jobSummary.Keys | Sort-Object)) {
            # Handle potential arrays in hashtable values
            $pendingCountValue = $jobSummary[$jobName]
            [int]$pendingCount = if ($pendingCountValue -is [array]) { $pendingCountValue[0] } else { $pendingCountValue }
           
            $transferredValue = $jobTransferred[$jobName]
            [double]$transferred = if ($transferredValue -is [array]) { $transferredValue[0] } else { $transferredValue }
           
            $oldestTaskValue = $jobOldestTask[$jobName]
            [long]$oldestTaskUsecs = if ($oldestTaskValue -is [array]) { $oldestTaskValue[0] } else { $oldestTaskValue }
            $oldestDate = Convert-UsecsToDate $oldestTaskUsecs
            $oldestDateShort = $oldestDate.Substring(0, 16)  # Just date and time, no seconds
           
            $remoteClusterValue = $jobRemoteCluster[$jobName]
            [string]$remoteCluster = if ($remoteClusterValue -is [array]) { $remoteClusterValue[0] } else { $remoteClusterValue }
           
            $totalPendingTasks = $totalPendingTasks + $pendingCount
            $totalTransferred = $totalTransferred + $transferred
           
            Write-Host ("{0,-44} {1,7}  {2,-16}     {3,-20}     {4,8}" -f $jobName, $pendingCount, $oldestDateShort, $remoteCluster, $transferred)
        }
       
        Write-Host ("-" * 120)
        Write-Host ("{0,-44} {1,7}  {2,-16}     {3,-20}     {4,8}" -f "TOTAL", $totalPendingTasks, "", "", $totalTransferred)
        Write-Host ("=" * 120)
       
        # Additional summary information
        Write-Host "`nSummary Information:" -ForegroundColor Cyan
        Write-Host "Total Jobs with Active Tasks: $($jobSummary.Count)"
        Write-Host "Total Pending Replication Tasks: $totalPendingTasks"
        Write-Host "Total Data Being Transferred: $totalTransferred $($units.ToUpper())"
    }
    else {
        # Display individual replication tasks
        Write-Host "`n=== INDIVIDUAL PENDING REPLICATION TASKS ===" -ForegroundColor Green
        Write-Host "Job Name                                    Task Start Time      Status           Remote Cluster           Run ID      $($units.ToUpper())"
        Write-Host "--------                                    ---------------      ------           --------------           ------      -------"
       
        [int]$totalPendingTasks = 0
        [double]$totalTransferred = 0
       
        # Sort tasks by start time (oldest first)
        $sortedTasks = $replicationTasks | Sort-Object TaskStartTimeUsecs
       
        foreach ($task in $sortedTasks) {
            $taskStartTimeShort = $task.TaskStartTime.Substring(0, 16)  # Just date and time, no seconds
            $totalPendingTasks++
            $totalTransferred += $task.TransferredData
           
            Write-Host ("{0,-44} {1,-16}     {2,-12}     {3,-20}     {4,8}      {5,8}" -f
                $task.JobName,
                $taskStartTimeShort,
                $task.Status,
                $task.RemoteCluster,
                $task.RunId,
                $task.TransferredData)
        }
       
        Write-Host ("-" * 140)
        Write-Host ("{0,-44} {1,-16}     {2,-12}     {3,-20}     {4,8}      {5,8}" -f
            "TOTAL ($totalPendingTasks tasks)", "", "", "", "", $totalTransferred)
        Write-Host ("=" * 140)
       
        # Additional summary information
        Write-Host "`nSummary Information:" -ForegroundColor Cyan
        Write-Host "Total Pending Replication Tasks: $totalPendingTasks"
        Write-Host "Total Data Being Transferred: $totalTransferred $($units.ToUpper())"
       
        if ($totalPendingTasks -gt 0) {
            $oldestTask = $sortedTasks[0]
            $newestTask = $sortedTasks[-1]
            Write-Host "Oldest Task: $($oldestTask.TaskStartTime) (Job: $($oldestTask.JobName))"
            Write-Host "Newest Task: $($newestTask.TaskStartTime) (Job: $($newestTask.JobName))"
        }
    }
   
    # Common information for both modes
    if ($remotecluster) {
        Write-Host "Filtered for Remote Cluster: $remotecluster"
    }
    if ($olderthan -gt 0) {
        Write-Host "Showing tasks older than: $olderthan days"
    }
    if ($youngerthan -gt 0) {
        Write-Host "Showing tasks younger than: $youngerthan days"
    }
}
else {
    Write-Host "`nNo pending replication tasks found" -ForegroundColor Yellow
   
    if ($jobnames.Count -gt 0) {
        Write-Host "Searched jobs: $($jobnames -join ', ')"
    }
    if ($remotecluster) {
        Write-Host "Remote cluster filter: $remotecluster"
    }
}