Clear-Host
$user = "username"                                     # Insert your user account here
$domain = "LOCAL"                         # Domain should be AD
$serverList = Get-Content "servers_colo.txt" # File Containing all Cluster names
$gflagimport = "importgflags.csv"             # Call to Get Gflag csv where the flags are set
$gflagimportscript = "gflags.ps1"             # Call the Gflag update script to execute


### Script Begin - DO NOT EDIT ###
foreach ($server in $serverList) {
    Write-Host $server
    Invoke-Expression "$gflagimportscript -vip $server.$domain -username $user -domain $domain -import $gflagimport -restart -effectiveNow"                  
}
### Script End ###