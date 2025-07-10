 ```powershell
 Get-WmiObject -Class Win32_Product | Where-Object { $_.Name -like "PowerShell 7*" } | ForEach-Object { $_.Uninstall() }
 ```