<#

.SYNOPSIS
# Retrieves and lists Cohesity protection groups.

.DESCRIPTION
# This script retrieves all Cohesity protection groups and lists their names and IDs.

.PARAMETER vip
# The VIP address of the Cohesity cluster.

.PARAMETER username
# The username for Cohesity API authentication.

.PARAMETER domain
# The domain for Cohesity API authentication (default is 'LOCAL').

.PARAMETER idFile	
# The path to the text file containing the protection group IDs for deletion. (default is "ids.txt" in the script directory).

.NOTES
Ensure that the Cohesity API PowerShell module is available and that the script has the necessary permissions to retrieve protection groups.
(cohesity-api.ps1 should be in the same directory or properly referenced)


.AUTHOR
Doug Austin
Date: 2025-06-30
Change Log:
# 25-06-30: Initial version created by Doug Austin

#>


param (
	[string]$vip,
	[string]$username,
	[string]$domain = 'LOCAL'
)

. "$PSScriptRoot\cohesity-api.ps1"

apiauth -vip $vip -username $username -domain $domain

$response = api get -v2 data-protect/protection-groups
$jobs = $response.protectionGroups

# List all protection group names
$protectionGroupNames = $jobs | Select-Object  name, id

# Output the names (for verification)
$protectionGroupNames



