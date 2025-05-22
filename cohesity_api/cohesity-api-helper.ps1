<#
.SYNOPSIS
This script is a wrapper around the Cohesity REST API for PowerShell, alone it only provides connectivity to a Cohesity cluster.

.PARAMETER vip
Cohesity cluster VIP or FQDN.

.PARAMETER username
Username for authentication.

.PARAMETER password
Password for authentication.

.PARAMETER domain
Domain for authentication (default: local).

.EXAMPLE
. .\cohesity-simple-api.ps1

.USAGE
.\cohesity-api-helper.ps1 -vip <ClusterVIP> -username <Username> -password <Password> -domain <Domain>

.NOTES
Author: Doug Austin  
Date: 2025-05-22

#>
# Simple state
$Global:CohesitySession = @{
    apiRoot = $null
    header  = @{}
    authorized = $false
}

function Connect-CohesityCluster {
    param(
        [Parameter(Mandatory)]
        [string]$vip,
        [Parameter(Mandatory)]
        [string]$username,
        [Parameter(Mandatory)]
        [string]$password,
        [string]$domain = 'local'
    )
    $Global:CohesitySession.apiRoot = "https://$vip/irisservices/api/v1"
    $Global:CohesitySession.header = @{
        'accept' = 'application/json'
        'content-type' = 'application/json'
    }
    $body = @{
        domain   = $domain
        username = $username
        password = $password
    } | ConvertTo-Json

    try {
        $resp = Invoke-RestMethod -Method Post -Uri "$($Global:CohesitySession.apiRoot)/public/accessTokens" -Body $body -Headers $Global:CohesitySession.header -SkipCertificateCheck
        $token = "$($resp.tokenType) $($resp.accessToken)"
        $Global:CohesitySession.header['authorization'] = $token
        $Global:CohesitySession.authorized = $true
        Write-Host "Connected to Cohesity cluster $vip" -ForegroundColor Green
    } catch {
        $Global:CohesitySession.authorized = $false
        Write-Host "Failed to connect: $_" -ForegroundColor Red
    }
}

function Invoke-CohesityApi {
    param(
        [Parameter(Mandatory)]
        [ValidateSet('get','post','put','delete','patch')]
        [string]$method,
        [Parameter(Mandatory)]
        [string]$uri,
        $body = $null
    )
    if (-not $Global:CohesitySession.authorized) {
        throw "Not connected. Use Connect-CohesityCluster first."
    }
    $url = if ($uri -like '/*') { "$($Global:CohesitySession.apiRoot)$uri" } else { "$($Global:CohesitySession.apiRoot)/$uri" }
    try {
        if ($body) {
            $jsonBody = $body | ConvertTo-Json -Depth 10
            return Invoke-RestMethod -Method $method -Uri $url -Headers $Global:CohesitySession.header -Body $jsonBody -SkipCertificateCheck
        } else {
            return Invoke-RestMethod -Method $method -Uri $url -Headers $Global:CohesitySession.header -SkipCertificateCheck
        }
    } catch {
        Write-Host "API call failed: $_" -ForegroundColor Red
        return $null
    }
}