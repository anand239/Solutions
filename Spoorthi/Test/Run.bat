@ECHO ON
CD /d "%~dp0"
Powershell.exe -ExecutionPolicy Bypass ".\Get-DPAReport.ps1 -ConfigFile .\config.json"