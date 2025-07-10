Clear-Host
$user = "username"                                     # Insert your user account here
$domain = "domain"                         # Domain should be AD
$serverList = Get-Content "<path to file>\servers.txt" # File Containing all Clusters
$gflagscript = "<path to file>\gflags.ps1"             # Call to Get Gflag Script


### Script Begin - DO NOT EDIT ###
foreach ($server in $serverList) {
    Write-Host $server
    Invoke-Expression "$gflagscript -vip $server.$domain -username $user -domain $domain"                  
}
### Script End ###