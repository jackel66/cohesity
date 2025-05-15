# Load Cohesity API Helper
# cohesity-api.ps1 must be in the same folder as this script
. .\cohesity-api.ps1

# Auth to Source Cluster
$vip = 'asx1cdp1dcl-az' 
$username = 'admin' # user with api access
$domain = 'local' # domain of user account
# Script will prompt for password

apiauth -vip $vip -username $username -domain $domain

# Read exported Routes
$routes = Get-Content -Raw -Path 'asx1bkascl-az.static_routes_export.json' | ConvertFrom-Json 

foreach ($route in $routes) {
    #remove readonly fields
    $route.PSobject.Properties.Remove('id')
    $route.PSObject.Properties.Remove('createdTime')

    try {
        $resp = api post /public/routes $route
        Write-Host "Imported route: $($route.destination) via $($route.gateway)"
    } catch {
        Write-Host "Failed to import route: $($route.destination)"
        Write-Host $_.Exception.Message
    }
}
