@ECHO ON
CD /d "%~dp0"
Powershell.exe -ExecutionPolicy Bypass ".\Get-DDCapacityReport.ps1 -ConfigFile .\config.json"
pause