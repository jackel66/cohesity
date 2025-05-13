Clear-Host
Write-Host "Starting Cleanup of Old Objects from all Clusters"

### Start Script ###
Write-Host "Checking SJX1 Collab A for Objects to remove" 
Z:\Scripts\Doug\Cohesity\unprotectMissingO365Objects.ps1 -vip sjx1bkaccl-az.cguser.capgroup.com `
						-username condoua2a `
                        -domain cguser.capgroup.com `

Write-Host "Checking SJX1 Collab B for Objects to remove" 
Z:\Scripts\Doug\Cohesity\unprotectMissingO365Objects.ps1 -vip sjx1bkbccl-az.cguser.capgroup.com `
						-username condoua2a `
                        -domain cguser.capgroup.com `

 Write-Host "Checking SJX1 Collab C for Objects to remove" 
Z:\Scripts\Doug\Cohesity\unprotectMissingO365Objects.ps1 -vip sjx1bkcccl-az.cguser.capgroup.com `
                        -username condoua2a `
                        -domain cguser.capgroup.com `

### End Script ###

Write-Host "Updating OneDrive"
Z:\Scripts\Doug\Cohesity\autoprotectO365.ps1 -vip sjx1bkbccl-az.cguser.capgroup.com `
						-username condoua2a `
                        -domain cguser.capgroup.com `
						-jobPrefix 'SJX1_Prod_OneDrive-' `
                        -objectType onedrive `
                        -maxObjectsPerJob 500 `
                        -policyName SJX1_Prod_O365 `
                        -sourceName capgroup.com `

Write-Host "Updating Sharepoint"
Z:\Scripts\Doug\Cohesity\autoprotectO365.ps1 -vip sjx1bkcccl-az.cguser.capgroup.com `
						-username condoua2a `
                        -domain cguser.capgroup.com `
						-jobPrefix 'SJX1_Prod_O365_SPO-' `
                        -objectType sites `
                        -maxObjectsPerJob 500 `
                        -policyName SJX1_Prod_O365 `
                        -sourceName capgroup.com `

Write-Host "Updating Exchange"
Z:\Scripts\Doug\Cohesity\autoprotectO365.ps1 -vip sjx1bkaccl-az.cguser.capgroup.com `
						-username condoua2a `
                        -domain cguser.capgroup.com `
						-jobPrefix 'SJX1_Prod_O365_ExchangeOnline-' `
                        -objectType mailbox `
                        -maxObjectsPerJob 500 `
                        -policyName SJX1_Prod_O365 `
                        -sourceName capgroup.com `

Write-Host "Updating Teams"
Z:\Scripts\Doug\Cohesity\autoprotectO365.ps1 -vip sjx1bkbccl-az.cguser.capgroup.com `
						-username condoua2a `
                        -domain cguser.capgroup.com `
						-jobPrefix 'SJX1_Prod_O365_Teams-' `
                        -objectType teams `
                        -maxObjectsPerJob 500 `
                        -policyName 'SJX1_Prod_O365' `
                        -sourceName capgroup.com `


