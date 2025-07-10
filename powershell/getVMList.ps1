

# Specify the path to the text file containing the vCenter server names
$vCenterFilePath = "vcenters.txt"

# Check if the file exists
if (-not (Test-Path $vCenterFilePath)) {
    Write-Host "The file $vCenterFilePath does not exist. Please create it and list vCenter servers line by line." -ForegroundColor Red
    exit
}

# Read the vCenter servers from the text file
$vCenterServers = Get-Content $vCenterFilePath

# Initialize an array to store results
$allVMDetails = @()

# Loop through each vCenter server
foreach ($vCenter in $vCenterServers) {
    try {
        Write-Host "Connecting to vCenter: $vCenter" -ForegroundColor Green
        Connect-VIServer -Server $vCenter -ErrorAction Stop

        # Get all powered-on VMs and their details
        $vmDetails = Get-VM | Where-Object { $_.PowerState -eq "PoweredOn" } | Select-Object -Property Name,
            @{Name="vCenter"; Expression={$vCenter}},
            @{Name="StorageProvisionedGB"; Expression={[Math]::Round($_.ProvisionedSpaceGB, 2)}},
            @{Name="StorageConsumedGB"; Expression={[Math]::Round($_.UsedSpaceGB, 2)}},
            @{Name="PowerState"; Expression={$_.PowerState}}

        # Add to the results array
        $allVMDetails += $vmDetails

        # Disconnect from the vCenter server
        Disconnect-VIServer -Confirm:$false
    }
    catch {
        Write-Host "Failed to connect to $vCenter. Skipping..." -ForegroundColor Yellow
    }
}

# Output to console
if ($allVMDetails.Count -gt 0) {
    $allVMDetails | Format-Table -AutoSize

    # Export to CSV
    $outputFile = "PoweredOnVMs_MultipleVCenters.csv"
    $allVMDetails | Export-Csv -Path $outputFile -NoTypeInformation -Encoding UTF8
    Write-Host "Results exported to $outputFile" -ForegroundColor Green
} else {
    Write-Host "No VM data collected. Ensure the vCenter servers are accessible and have VMs powered on." -ForegroundColor Red
}
