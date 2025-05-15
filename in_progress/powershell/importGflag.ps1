Clear-Host
$user = "admin"                                     # Insert your user account here
$domain = "local"                         # Domain should be AD
$serverList = Get-Content "Z:\Cohesity\Scripts\Doug\servers_colo.txt" # File Containing all Cluster names
$gflagimport = "Z:\Cohesity\Scripts\Doug\Cohesity\importgflags.csv"             # Call to Get Gflag csv where the flags are set
$gflagimportscript = "Z:\Cohesity\Scripts\Doug\Cohesity\gflags.ps1"             # Call the Gflag update script to execute


### Script Begin - DO NOT EDIT ###
foreach ($server in $serverList) {
    Write-Host $server
    Invoke-Expression "$gflagimportscript -vip $server -username $user -domain $domain -import $gflagimport -effectiveNow"                  
}
### Script End ###