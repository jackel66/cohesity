Clear-Host
$user = "condoua2a"                                     # Insert your user account here
$domain = "cguser.capgroup.com"                         # Domain should be AD
$serverList = Get-Content "Z:\Cohesity\Scripts\Doug\servers.txt" # File Containing all Clusters
$gflagscript = "Z:\Cohesity\Scripts\Doug\Cohesity\gflags.ps1"             # Call to Get Gflag Script


### Script Begin - DO NOT EDIT ###
foreach ($server in $serverList) {
    Write-Host $server
    Invoke-Expression "$gflagscript -vip $server.$domain -username $user -domain $domain"                  
}
### Script End ###