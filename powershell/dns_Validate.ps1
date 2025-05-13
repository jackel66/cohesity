# . . . . . . . . . . . . . . . . . . .
#  PowerShell Module for Checking DNS Forward and Reverse 
#  Version 2025.02.13 - Doug Austin
# . . . . . . . . . . . . . . . . . . .
#
# 2025.02.13 - Initial Build
#
#


# Import Module
Import-Module ImportExcel

# Source File
$ExcelFilePath = "C:\temp\iplookup.xlsx" # Add path to xlsx file you wish to use as input.

# File Structure should be as following in an xlsx file.
# column A with Row 1 being a header row, Header should be "IP_Address"
# column B will have header "Hostname" with FQDN and not short name
# If either of these are not structured properly the script will fail. 

# Output file will be in same location as source .XLSX file.
$ExcelFolder = Split-Path -Parent $ExcelFilePath
$OutputFilePath = Join-Path -Path $ExcelFolder -ChildPath "DNS_Verify.txt" # Output File Name

# Output File Logging
"" | Out-File -FilePath $OutputFilePath # Clears file if this is rerun

Write-Host "" # adding a space after initiation

# Read File
$Data = Import-Excel -Path $ExcelFilePath

#Begin Forward lookup
foreach ($Entry in $Data) {
    $IP = $Entry.IP_Address #Ip Address
    $ExpectedHostname = $Entry.Hostname #Expected Hostname
    try {
        $ActualHostname = [System.Net.Dns]::GetHostEntry($IP).HostName
        if ($ActualHostname -eq $ExpectedHostname) {
            "INFO: Forward Lookup Passed: $IP -> $ExpectedHostname" | Tee-Object -FilePath $OutputFilePath -Append
        } else {
            "ERROR: Forward Lookup Failed $IP resolved to $ActualHostname instead of $ExpectedHostname" | Tee-Object -FilePath $OutputFilePath -Append
        }
    } catch {
        "ERROR: Forward lookup Error: Could not resolve IP $IP" | Tee-Object -FilePath $OutputFilePath -Append
    }
    # Begin Reverse Lookup
    try {
        $ResolvedIPs = [System.Net.Dns]::GetHostAddresses($ExpectedHostname) | ForEach-Object { $_.IPAddressToString }
        if ($ResolvedIPs -contains $IP) {
            "INFO: Reverse Lookup passed: $ExpectedHostname -> $IP" | Tee-Object -FilePath $OutputFilePath -Append
        } else {
            "ERROR: Reverse Lookup Failed: $ExpectedHostname resolved to $($ResolvedIPs -join ', ') instead of $IP" | Tee-Object -FilePath $OutputFilePath -Append
        }
    } catch {
        "ERROR: Reverse Lookup Error: Could not resolve Hostname $ExpectedHostname" | Tee-Object -FilePath $OutputFilePath -Append
    }
    # Add space 
    "" | Tee-Object -FilePath $OutputFilePath -Append
}