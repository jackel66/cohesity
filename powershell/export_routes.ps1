# Load Cohesity API Helper
# cohesity-api.ps1 must be in the same folder as this script (https://github.com/bseltz-cohesity/scripts/blob/master/powershell/cohesity-api/cohesity-api.ps1)
. .\cohesity-api.ps1

# Auth to Source Cluster
$vip = 'hostname'
$username = 'admin' # user with api access
$domain = 'local' # domain of user account

# Script will prompt for password
apiauth -vip $vip -username $username -domain $domain

# Export Routes
$routes = api get /public/routes
Write-Host $routes
$routes | ConvertTo-Json -Depth 10 | Out-File -FilePath "$($vip).static_routes_export.json"" -Encoding utf8
 
Write-host "Exported $($routes.Count) routes to $($vip).static-routes-export.json"