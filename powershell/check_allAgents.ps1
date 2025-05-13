Clear-Host
$user = "userrname"                                     # Insert your user account here
$domain = "local"                         # Domain should be AD
$serverList = Get-Content "File Path for Cohesity Clusters" # File Containing all Clusters
$gflagscript = "Path to agent Scrip \ agentVersions.ps1"             # Call to Get Gflag Script


### Script Begin - DO NOT EDIT ###
foreach ($server in $serverList) {
    Write-Host $server
    Invoke-Expression "$gflagscript -vip $server.$domain -username $user -domain $domain"                  
}
### Script End ###