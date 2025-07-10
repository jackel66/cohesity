$pwshPath = "C:\Program Files\PowerShell\7"
[Environment]::SetEnvironmentVariable("Path", $env:Path + ";$pwshPath", [EnvironmentVariableTarget]::Machine)