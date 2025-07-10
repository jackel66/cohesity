param (
    [Parameter(Mandatory)]
    [string]$sourcezvma,
    [Parameter(Mandatory)]
    [string]$username,
    [Parameter(Mandatory)]
    [string]$domain,
    [Parameter()]
    [switch]$AsJson
)

function Get-ZertoSession {
    param (
        [string]$ZertoHost,
        [string]$User,
        [string]$Domain
    )
    $secpasswd = Read-Host "Enter password for $User@$Domain" -AsSecureString
    $creds = New-Object System.Management.Automation.PSCredential ("$Domain\$User", $secpasswd)
    $headers = @{
        "Accept" = "application/json"
    }
    $body = @{
        Username = $User
        Password = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($secpasswd))
        Domain   = $Domain
    }
    $uri = "https://$ZertoHost:9669/v1/session/add"
    try {
        $response = Invoke-RestMethod -Uri $uri -Method Post -Body ($body | ConvertTo-Json) -Headers $headers -ContentType "application/json" -SkipCertificateCheck
        return $response.Session
    } catch {
        Write-Error "Failed to authenticate to Zerto ZVMA: $_"
        exit 1
    }
}

function Get-ZertoData {
    param (
        [string]$ZertoHost,
        [string]$Session
    )
    $headers = @{
        "Accept" = "application/json"
        "x-zerto-session" = $Session
    }
    $baseUri = "https://$ZertoHost:9669/v1"
    $results = @{}

    $endpoints = @{
        Events = "$baseUri/events"
        Alerts = "$baseUri/alerts"
        VPGs   = "$baseUri/vpgs"
    }

    foreach ($key in $endpoints.Keys) {
        try {
            $results[$key] = Invoke-RestMethod -Uri $endpoints[$key] -Headers $headers -SkipCertificateCheck
        } catch {
            $results[$key] = "Error: $_"
        }
    }

    # RPO is part of VPGs, extract if present
    if ($results["VPGs"] -is [System.Collections.IEnumerable]) {
        $results["RPO"] = $results["VPGs"] | Select-Object Name, @{N="RPO (Seconds)";E={ $_.ActualRPOInSeconds }}
    }

    return $results
}

# Main
$session = Get-ZertoSession -ZertoHost $sourcezvma -User $username -Domain $domain
$data = Get-ZertoData -ZertoHost $sourcezvma -Session $session

if ($AsJson) {
    $data | ConvertTo-Json -Depth 5 | Out-File "ZertoExport.json"
    Write-Host "Exported Zerto data to ZertoExport.json" -ForegroundColor Green
} else {
    Write-Host "`n--- Events ---" -ForegroundColor Cyan
    $data.Events | Format-Table -AutoSize
    Write-Host "`n--- Alerts ---" -ForegroundColor Cyan
    $data.Alerts | Format-Table -AutoSize
    Write-Host "`n--- VPG Status ---" -ForegroundColor Cyan
    $data.VPGs | Format-Table Name, Status, State, ActualRPOInSeconds -AutoSize
    Write-Host "`n--- RPO ---" -ForegroundColor Cyan
    $data.RPO | Format-Table -AutoSize
}