@ECHO ON
CD /d "%~dp0"
Powershell.exe -ExecutionPolicy Bypass ".\Get-SRMVersion.ps1 -ConfigFile .\config.json"